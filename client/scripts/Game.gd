extends Control

@onready var info_label: Label = $MainVBox/InfoLabel
@onready var hint_label: Label = $MainVBox/HintLabel
@onready var hint_input: LineEdit = $MainVBox/HintInput
@onready var score_container: VBoxContainer = $MainVBox/ScoreContainer
@onready var grid: GridContainer = $MainVBox/GridContainer

func _ready():
	_create_grid()
	_refresh_scores()
	NetworkManager.hint_received.connect(_on_hint_received)
	NetworkManager.tile_selected.connect(_on_tile_selected)
	info_label.text = "Ti si Cue Giver" if Session.secret_tile.size() > 0 else "Pogadjaj boju"

func _create_grid():
	for child in grid.get_children():
		child.queue_free()
	for y in range(16):
		for x in range(30):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(20, 20)
			btn.modulate = Color.from_hsv(float(x) / 30.0, 0.5 + float(y) / 40.0, 1.0)
			btn.pressed.connect(_on_tile_pressed.bind(x, y))
			grid.add_child(btn)

func _on_tile_pressed(x: int, y: int):
	NetworkManager.send_data({"type": "select_tile", "tileX": x, "tileY": y})

func _on_send_hint_button_pressed():
	var hint := hint_input.text.strip_edges()
	if hint == "":
		return
	NetworkManager.send_data({"type": "submit_hint", "hint": hint})
	hint_input.text = ""

func _on_hint_received(data):
	hint_label.text = "Hint: " + data.get("hint", "")

func _on_tile_selected(data):
	var index := int(data.get("tileY", 0)) * 30 + int(data.get("tileX", 0))
	if index >= 0 and index < grid.get_child_count():
		grid.get_child(index).text = "X"

func _refresh_scores():
	for child in score_container.get_children():
		child.queue_free()
	for player in Session.players:
		var label := Label.new()
		label.text = "%s: %s" % [player.get("name", "Igrac"), str(player.get("score", 0))]
		score_container.add_child(label)
