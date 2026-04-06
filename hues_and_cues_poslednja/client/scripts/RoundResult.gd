extends Control

@onready var correct_tile_label: Label = $Center/VBox/CorrectTileLabel
@onready var scores_container: VBoxContainer = $Center/VBox/ScoresContainer
@onready var continue_label: Label = $Center/VBox/ContinueInfoLabel

func _ready():
	if not NetworkManager.game_started.is_connected(_on_game_started):
		NetworkManager.game_started.connect(_on_game_started)
	if not NetworkManager.game_over_received.is_connected(_on_game_over_received):
		NetworkManager.game_over_received.connect(_on_game_over_received)

	correct_tile_label.text = "Tacno polje: (%s, %s)" % [
		str(Session.correct_tile.get("x", -1)),
		str(Session.correct_tile.get("y", -1))
	]

	for child in scores_container.get_children():
		child.queue_free()

	for item in Session.round_scores:
		var label := Label.new()
		label.text = "%s +%s" % [item.get("name", "Igrac"), str(item.get("delta", 0))]
		scores_container.add_child(label)

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
		label.text = "%s: %s" % [player.get("name", "Igrac"), str(player.get("score", 0))]
		scores_container.add_child(label)
	continue_label.text = "Partija je zavrsena."
