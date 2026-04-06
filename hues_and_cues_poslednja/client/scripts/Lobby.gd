extends Control

@onready var room_code_label: Label = $MainMargin/VBox/RoomCodeLabel
@onready var host_label: Label = $MainMargin/VBox/HostLabel
@onready var players_container: VBoxContainer = $MainMargin/VBox/PlayersContainer
@onready var ready_button: Button = $MainMargin/VBox/ButtonsHBox/ReadyButton
@onready var start_button: Button = $MainMargin/VBox/ButtonsHBox/StartButton
@onready var status_label: Label = $MainMargin/VBox/StatusLabel

var is_ready := false

func _ready():
	if not NetworkManager.lobby_updated.is_connected(_on_lobby_updated):
		NetworkManager.lobby_updated.connect(_on_lobby_updated)
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.error_received.is_connected(_on_error_received):
		NetworkManager.error_received.connect(_on_error_received)
	_refresh_ui()

func _refresh_ui():
	room_code_label.text = "Kod sobe: " + Session.room_code
	host_label.text = "Host ID: " + Session.host_id

	for child in players_container.get_children():
		child.queue_free()

	for player in Session.players:
		var label := Label.new()
		var ready_text := "Ready" if player.get("ready", false) else "Not Ready"
		label.text = "%s - %s" % [player.get("name", "Igrac"), ready_text]
		players_container.add_child(label)

	start_button.visible = Session.player_id == Session.host_id
	ready_button.text = "Not Ready" if is_ready else "Ready"

func _on_ready_button_pressed():
	is_ready = not is_ready
	ready_button.text = "Not Ready" if is_ready else "Ready"
	NetworkManager.send_data({"type": "player_ready", "ready": is_ready})

func _on_start_button_pressed():
	NetworkManager.send_data({"type": "start_game"})

func _on_lobby_updated(data):
	_refresh_ui()
	status_label.text = "Svi su spremni" if data.get("canStart", false) else "Cekanje igraca..."

func _on_game_started(_data):
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_error_received(message):
	status_label.text = message
