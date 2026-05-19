extends Control

@onready var player_name_label: Label = $Center/VBox/PlayerNameLabel
@onready var correct_tile_label: Label = $Center/VBox/CorrectTileLabel
@onready var color_preview: ColorRect = $Center/VBox/ColorCardPanel/ColorCardVBox/ColorPreview
@onready var next_cue_label: Label = $Center/VBox/NextCueLabel
@onready var scores_container: VBoxContainer = $Center/VBox/ScoresContainer
@onready var continue_label: Label = $Center/VBox/ContinueInfoLabel
@onready var ready_next_round_button: Button = $Center/VBox/ReadyNextRoundButton

func _ready():
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.game_over_received.is_connected(_on_game_over_received):
		NetworkManager.game_over_received.connect(_on_game_over_received)

	player_name_label.text = "Ti si: " + Session.player_name
	correct_tile_label.text = "Tačna kartica: %s" % str(Session.correct_tile.get("code", ""))
	var c = Session.correct_tile.get("color", {"r": 1.0, "g": 1.0, "b": 1.0})
	color_preview.color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), 1.0)
	next_cue_label.text = "✨ Sledeći Cue Giver: %s ✨" % Session.next_cue_giver_name

	for child in scores_container.get_children():
		child.queue_free()
	for item in Session.round_scores:
		var label := Label.new()
		label.text = "%s +%s" % [item.get("name", "Igrač"), str(item.get("delta", 0))]
		scores_container.add_child(label)

	var am_i_next = Session.player_id == Session.next_cue_giver_id
	ready_next_round_button.visible = am_i_next
	continue_label.text = "Čeka se da sledeći Cue Giver potvrdi da je spreman."

func _on_ready_next_round_button_pressed():
	ready_next_round_button.disabled = true
	NetworkManager.send_data({"type": "next_round_ready"})

func _on_game_started(_data):
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_game_over_received(data):
	for child in scores_container.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Kraj igre"
	scores_container.add_child(title)
	for player in data.get("players", []):
		var label := Label.new()
		label.text = "%s: %s" % [player.get("name", "Igrač"), str(player.get("score", 0))]
		scores_container.add_child(label)
	continue_label.text = "Partija je završena."
	ready_next_round_button.visible = false