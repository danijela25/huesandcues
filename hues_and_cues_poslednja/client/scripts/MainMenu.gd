extends Control

@onready var name_input: LineEdit = $CenterBox/VBoxContainer/NameInput
@onready var room_code_input: LineEdit = $CenterBox/VBoxContainer/RoomCodeInput
@onready var error_label: Label = $CenterBox/VBoxContainer/ErrorLabel

var scene_changing := false

func _ready():
	Session.reset_game_state()
	NetworkManager.connect_to_server()

	if not NetworkManager.room_created.is_connected(_on_room_created):
		NetworkManager.room_created.connect(_on_room_created)

	if not NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
		NetworkManager.lobby_updated.connect(_on_lobby_updated)

	if not NetworkManager.error_received.is_connected(_on_error_received):
		NetworkManager.error_received.connect(_on_error_received)

func _on_create_room_button_pressed():
	var player_name := name_input.text.strip_edges()
	if player_name == "":
		error_label.text = "Unesi ime"
		return
	Session.player_name = player_name
	error_label.text = ""
	NetworkManager.send_data({"type": "create_room", "playerName": player_name})

func _on_join_room_button_pressed():
	var player_name := name_input.text.strip_edges()
	var room_code := room_code_input.text.strip_edges().to_upper()
	if player_name == "" or room_code == "":
		error_label.text = "Unesi ime i kod sobe"
		return
	Session.player_name = player_name
	error_label.text = ""
	NetworkManager.send_data({"type": "join_room", "playerName": player_name, "roomCode": room_code})

func _on_room_created(_data):
	if scene_changing:
		return
	scene_changing = true
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_lobby_updated(_data):
	if scene_changing:
		return
	scene_changing = true
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_error_received(message):
	error_label.text = message
