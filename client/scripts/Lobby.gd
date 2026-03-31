extends Control

@onready var room_code_label: Label = $VBoxContainer/RoomCodeLabel
@onready var players_container: VBoxContainer = $VBoxContainer/PlayersContainer
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var is_ready := false

func _ready():
    NetworkManager.lobby_updated.connect(_on_lobby_updated)
    NetworkManager.game_started.connect(_on_game_started)
    NetworkManager.error_received.connect(_on_error_received)
    _refresh_ui()

func _refresh_ui():
    room_code_label.text = "Kod sobe: " + Session.room_code
    for child in players_container.get_children():
        child.queue_free()
    for player in Session.players:
        var label := Label.new()
        label.text = "%s - %s" % [player.get("name", "Igrac"), "Ready" if player.get("ready", false) else "Not Ready"]
        players_container.add_child(label)
    start_button.visible = Session.player_id == Session.host_id

func _on_ready_button_pressed():
    is_ready = !is_ready
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