extends Control

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var room_code_input: LineEdit = $VBoxContainer/RoomCodeInput
@onready var error_label: Label = $VBoxContainer/ErrorLabel

var scene_changing := false


func _ready():

	name_input.text = ""
	room_code_input.text = ""
	error_label.text = ""

	if not NetworkManager.room_created.is_connected(_on_room_created):
		NetworkManager.room_created.connect(_on_room_created)

	if not NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
		NetworkManager.lobby_updated.connect(_on_lobby_updated)

	if not NetworkManager.error_received.is_connected(_on_error_received):
		NetworkManager.error_received.connect(_on_error_received)

	if not NetworkManager.reconnect_succeeded.is_connected(_on_reconnect_succeeded):
		NetworkManager.reconnect_succeeded.connect(_on_reconnect_succeeded)

	if not NetworkManager.reconnect_failed.is_connected(_on_reconnect_failed):
		NetworkManager.reconnect_failed.connect(_on_reconnect_failed)

	if not NetworkManager.connected.is_connected(_on_connected):
		NetworkManager.connected.connect(_on_connected)


	var has_saved_session := Session.load_reconnect_data()

	print(
		"SAVED SESSION: ",
		has_saved_session,
		" PLAYER: ",
		Session.player_id,
		" ROOM: ",
		Session.room_code
	)


	# prvo pokrecem socket
	NetworkManager.connect_to_server()


	# onda kazemo da treba reconnect
	if has_saved_session:

		print("POKUSAVAM RECONNECT")

		NetworkManager.request_saved_reconnect()

	else:

		Session.reset_game_state()
func _on_create_room_button_pressed():

	var entered_name := name_input.text.strip_edges()

	if entered_name == "":
		error_label.text = "Unesi ime"
		return

	Session.player_name = entered_name

	if NetworkManager.socket.get_ready_state() != \
	WebSocketPeer.STATE_OPEN:

		error_label.text = \
			"Povezivanje sa serverom..."

		return

	error_label.text = ""

	NetworkManager.send_data({
		"type": "create_room",
		"playerName": entered_name
	})


func _on_join_room_button_pressed():

	var entered_name := name_input.text.strip_edges()

	var room_code := \
		room_code_input.text.strip_edges().to_upper()

	if entered_name == "" or room_code == "":
		error_label.text = "Unesi ime i kod sobe"
		return

	Session.player_name = entered_name

	if NetworkManager.socket.get_ready_state() != \
	WebSocketPeer.STATE_OPEN:

		error_label.text = \
			"Povezivanje sa serverom... sačekaj 2 sekunde pa klikni opet"

		return

	error_label.text = ""

	NetworkManager.send_data({
		"type": "join_room",
		"playerName": entered_name,
		"roomCode": room_code
	})


func _on_room_created(_data):

	if scene_changing:
		return

	scene_changing = true

	get_tree().change_scene_to_file(
		"res://scenes/Lobby.tscn"
	)


func _on_lobby_updated(_data):

	if scene_changing:
		return

	scene_changing = true

	get_tree().change_scene_to_file(
		"res://scenes/Lobby.tscn"
	)


func _on_error_received(message):

	error_label.text = message


func _on_reconnect_succeeded(data):

	if scene_changing:
		return

	scene_changing = true

	var status := str(
		data.get(
			"status",
			"playing"
		)
	)

	if status == "lobby":

		get_tree().change_scene_to_file(
			"res://scenes/Lobby.tscn"
		)

	else:

		get_tree().change_scene_to_file(
			"res://scenes/Game.tscn"
		)
func _on_connected():

	print("MAIN MENU - SOCKET OPEN")

	if error_label.text.begins_with(
		"Povezivanje sa serverom"
	):
		error_label.text = ""
func _on_reconnect_failed(message):

	NetworkManager.cancel_reconnect()

	Session.reset_game_state()

	name_input.text = ""
	room_code_input.text = ""
	error_label.text = message
