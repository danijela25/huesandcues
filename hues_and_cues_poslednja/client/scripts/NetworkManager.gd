extends Node

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

var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:3000"
var connected_flag := false

func _process(_delta):
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not connected_flag:
		connected_flag = true
		connected.emit()

	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED and connected_flag:
		connected_flag = false
		disconnected.emit()

	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(raw)
		if typeof(data) == TYPE_DICTIONARY:
			_handle_message(data)

func connect_to_server():
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	var err := socket.connect_to_url(server_url)
	if err != OK:
		push_error("Ne mogu da se povezem na server")

func send_data(data: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func _handle_message(data: Dictionary):
	match data.get("type", ""):
		"room_created":
			Session.room_code = data.get("roomCode", "")
			Session.player_id = data.get("playerId", "")
			room_created.emit(data)
		"lobby_state":
			Session.room_code = data.get("roomCode", "")
			Session.host_id = data.get("hostId", "")
			Session.players = data.get("players", [])
			lobby_updated.emit(data)
		"game_start":
			Session.players = data.get("players", [])
			Session.current_round = data.get("roundNumber", 1)
			Session.current_phase = data.get("phase", "")
			Session.cue_giver_id = data.get("cueGiverId", "")
			Session.current_hint = ""
			Session.correct_tile = {}
			Session.secret_tile = {}
			game_started.emit(data)
		"secret_tile":
			Session.secret_tile = {"x": data.get("tileX", -1), "y": data.get("tileY", -1)}
			secret_tile_received.emit(data)
		"state_update":
			Session.players = data.get("players", Session.players)
			Session.current_round = data.get("roundNumber", Session.current_round)
			Session.current_phase = data.get("phase", Session.current_phase)
			Session.cue_giver_id = data.get("cueGiverId", Session.cue_giver_id)
			Session.current_hint = data.get("hint", Session.current_hint)
			state_updated.emit(data)
		"round_result":
			Session.players = data.get("players", Session.players)
			Session.correct_tile = data.get("correctTile", {})
			Session.round_scores = data.get("roundScores", [])
			round_result_received.emit(data)
		"game_over":
			Session.players = data.get("players", Session.players)
			game_over_received.emit(data)
		"error":
			error_received.emit(data.get("message", "Greska"))
