extends Node

signal player_left_received(data)
signal connected
signal disconnected
signal room_created(data)
signal lobby_updated(data)
signal game_started(data)
signal secret_tile_received(data)
signal state_updated(data)
signal round_result_received(data)
signal game_over_received(data)
signal error_received(message)
signal game_frozen(data)
signal game_resumed(data)
signal reconnect_failed(message)
signal reconnect_succeeded(data)

var socket := WebSocketPeer.new()
var server_url := "wss://huesandcues.onrender.com"
#var server_url := "ws://127.0.0.1:3000"

var connected_flag := false

var reconnecting := false
var reconnect_on_connect := false

var reconnect_elapsed := 0.0
var reconnect_retry_elapsed := 0.0
var initial_connect_retry := 0.0

const RECONNECT_LIMIT := 120.0
const RECONNECT_RETRY := 3.0


func _process(_delta):

	socket.poll()

	var state := socket.get_ready_state()


	
	if state == WebSocketPeer.STATE_OPEN and not connected_flag:

		connected_flag = true
		initial_connect_retry = 0.0

		print("POVEZAN NA SERVER")

		connected.emit()

		if reconnecting or reconnect_on_connect:
			_send_reconnect_request()


	# =========================
	# VEZA JE PREKINUTA
	# =========================

	if state == WebSocketPeer.STATE_CLOSED and connected_flag:

		connected_flag = false

		print("VEZA SA SERVEROM JE PREKINUTA")

		disconnected.emit()

		if Session.player_id != "" and Session.room_code != "":

			reconnecting = true
			reconnect_on_connect = false

			reconnect_elapsed = 0.0
			reconnect_retry_elapsed = 0.0


	# =========================
	# PRVO POVEZIVANJE
	# =========================

	if (
		state == WebSocketPeer.STATE_CLOSED
		and not connected_flag
		and not reconnecting
	):

		initial_connect_retry += _delta

		if initial_connect_retry >= 3.0:

			initial_connect_retry = 0.0

			connect_to_server()

	else:
		initial_connect_retry = 0.0


	# =========================
	# RECONNECT
	# =========================

	if reconnecting:

		reconnect_elapsed += _delta

		if state == WebSocketPeer.STATE_CLOSED:

			reconnect_retry_elapsed += _delta

			if reconnect_retry_elapsed >= RECONNECT_RETRY:

				reconnect_retry_elapsed = 0.0

				connect_to_server()

		else:
			reconnect_retry_elapsed = 0.0


		if reconnect_elapsed >= RECONNECT_LIMIT:

			cancel_reconnect()

			Session.reset_game_state()

			reconnect_failed.emit(
				"Nije uspelo ponovno povezivanje u roku od 2 minuta."
			)


	# =========================
	# PRIMANJE PORUKA
	# =========================

	while socket.get_available_packet_count() > 0:

		var raw := socket.get_packet().get_string_from_utf8()

		var data = JSON.parse_string(raw)

		if typeof(data) == TYPE_DICTIONARY:

			print("PRIMLJENO: ", data)

			_handle_message(data)


func connect_to_server():

	var state := socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		return

	if state == WebSocketPeer.STATE_CONNECTING:
		return

	socket = WebSocketPeer.new()

	var err := socket.connect_to_url(server_url)

	if err != OK:

		push_error(
			"Ne mogu da se povežem na server. Error: " + str(err)
		)

	else:

		print("POKRENUTO POVEZIVANJE SA SERVEROM")


func request_saved_reconnect():

	if Session.player_id == "" or Session.room_code == "":
		return

	reconnect_on_connect = true

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send_reconnect_request()


func _send_reconnect_request():

	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	if Session.player_id == "" or Session.room_code == "":
		return

	reconnect_on_connect = false

	if not reconnecting:

		reconnecting = true

		reconnect_elapsed = 0.0
		reconnect_retry_elapsed = 0.0

	send_data({
		"type": "reconnect",
		"playerId": Session.player_id,
		"roomCode": Session.room_code
	})


func cancel_reconnect():

	reconnecting = false
	reconnect_on_connect = false

	reconnect_elapsed = 0.0
	reconnect_retry_elapsed = 0.0


func send_data(data: Dictionary):

	print(
		"SALJEM: ",
		data,
		" STATE: ",
		socket.get_ready_state()
	)

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:

		socket.send_text(
			JSON.stringify(data)
		)

	else:

		print("NIJE POVEZAN NA SERVER")


func _handle_message(data: Dictionary):

	match data.get("type", ""):


		# =========================
		# SOBA
		# =========================

		"room_created", "joined_room":

			cancel_reconnect()

			Session.room_code = data.get(
				"roomCode",
				""
			)

			Session.player_id = data.get(
				"playerId",
				""
			)

			Session.save_reconnect_data()

			room_created.emit(data)


		# =========================
		# LOBBY
		# =========================

		"lobby_state":

			Session.room_code = data.get(
				"roomCode",
				Session.room_code
			)

			Session.host_id = data.get(
				"hostId",
				""
			)

			Session.players = data.get(
				"players",
				[]
			)

			lobby_updated.emit(data)


		# =========================
		# POČETAK IGRE
		# =========================

		"game_start":

			Session.players = data.get(
				"players",
				[]
			)

			Session.current_round = data.get(
				"roundNumber",
				1
			)

			Session.current_phase = data.get(
				"phaseLabel",
				""
			)

			Session.cue_giver_id = data.get(
				"cueGiverId",
				""
			)

			Session.current_hint = ""

			Session.correct_tile = {}
			Session.secret_tile = {}

			Session.current_guesser_id = data.get(
				"currentGuesserId",
				""
			)

			Session.current_guesser_name = data.get(
				"currentGuesserName",
				""
			)

			Session.pending_tile_x = -1
			Session.pending_tile_y = -1

			Session.replay_votes = []

			game_started.emit(data)


		# =========================
		# TAJNA KARTICA
		# =========================

		"secret_tile":

			Session.secret_tile = {
				"x": data.get("tileX", -1),
				"y": data.get("tileY", -1),
				"code": data.get("tileCode", ""),
				"color": data.get(
					"color",
					{
						"r": 1.0,
						"g": 1.0,
						"b": 1.0
					}
				)
			}

			secret_tile_received.emit(data)


		# =========================
		# STATE UPDATE
		# =========================

		"state_update":

			Session.players = data.get(
				"players",
				Session.players
			)

			Session.current_round = data.get(
				"roundNumber",
				Session.current_round
			)

			Session.current_phase = data.get(
				"phaseLabel",
				Session.current_phase
			)

			Session.cue_giver_id = data.get(
				"cueGiverId",
				Session.cue_giver_id
			)

			Session.current_hint = data.get(
				"hint",
				Session.current_hint
			)

			Session.current_guesser_id = data.get(
				"currentGuesserId",
				Session.current_guesser_id
			)

			Session.current_guesser_name = data.get(
				"currentGuesserName",
				Session.current_guesser_name
			)

			state_updated.emit(data)


		# =========================
		# REZULTAT RUNDE
		# =========================

		"round_result":

			Session.players = data.get(
				"players",
				Session.players
			)

			Session.correct_tile = data.get(
				"correctTile",
				{}
			)

			Session.round_scores = data.get(
				"roundScores",
				[]
			)

			Session.next_cue_giver_id = data.get(
				"nextCueGiverId",
				""
			)

			Session.next_cue_giver_name = data.get(
				"nextCueGiverName",
				""
			)

			Session.current_guesser_id = ""
			Session.current_guesser_name = ""

			Session.pending_tile_x = -1
			Session.pending_tile_y = -1

			round_result_received.emit(data)


		# =========================
		# KRAJ IGRE
		# =========================

		"game_over":

			Session.players = data.get(
				"players",
				Session.players
			)

			Session.replay_votes = data.get(
				"replayVotes",
				[]
			)

			game_over_received.emit(data)


		# =========================
		# REPLAY
		# =========================

		"replay_vote_update":

			Session.replay_votes = data.get(
				"replayVotes",
				[]
			)

			state_updated.emit(data)


		# =========================
		# GREŠKA
		# =========================

		"error":

			error_received.emit(
				data.get(
					"message",
					"Greška"
				)
			)


		# =========================
		# IGRAČ JE NAPUSTIO
		# =========================

		"player_left":

			player_left_received.emit(data)


		# =========================
		# IGRA ZAMRZNUTA
		# =========================

		"game_frozen":

			game_frozen.emit(data)


		# =========================
		# IGRA NASTAVLJENA
		# =========================

		"game_resumed":

			game_resumed.emit(data)


		# =========================
		# USPEŠAN RECONNECT
		# =========================

		"reconnected":

			Session.room_code = data.get(
				"roomCode",
				Session.room_code
			)

			Session.player_id = data.get(
				"playerId",
				Session.player_id
			)

			Session.save_reconnect_data()

			cancel_reconnect()

			reconnect_succeeded.emit(data)


		# =========================
		# NEUSPEŠAN RECONNECT
		# =========================

		"reconnect_failed":

			cancel_reconnect()

			Session.reset_game_state()

			reconnect_failed.emit(
				data.get(
					"message",
					"Povratak u igru nije moguć."
				)
			)
