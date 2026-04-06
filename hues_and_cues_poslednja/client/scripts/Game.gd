extends Control

@onready var round_label: Label = $RootMargin/HBox/LeftPanel/RoundLabel
@onready var phase_label: Label = $RootMargin/HBox/LeftPanel/PhaseLabel
@onready var cue_giver_label: Label = $RootMargin/HBox/LeftPanel/CueGiverLabel
@onready var hint_label: Label = $RootMargin/HBox/LeftPanel/HintLabel
@onready var secret_tile_label: Label = $RootMargin/HBox/LeftPanel/SecretTileLabel
@onready var hint_input: LineEdit = $RootMargin/HBox/LeftPanel/HintInput
@onready var send_hint_button: Button = $RootMargin/HBox/LeftPanel/SendHintButton
@onready var info_label: Label = $RootMargin/HBox/LeftPanel/InfoLabel
@onready var score_container: VBoxContainer = $RootMargin/HBox/LeftPanel/ScoreContainer
@onready var grid: GridContainer = $RootMargin/HBox/GridPanel/GridMargin/GridContainer

var tile_buttons: Array = []

func _ready():
	if not NetworkManager.secret_tile_received.is_connected(_on_secret_tile_received):
		NetworkManager.secret_tile_received.connect(_on_secret_tile_received)
	if not NetworkManager.state_updated.is_connected(_on_state_updated):
		NetworkManager.state_updated.connect(_on_state_updated)
	if not NetworkManager.round_result_received.is_connected(_on_round_result_received):
		NetworkManager.round_result_received.connect(_on_round_result_received)
	if not NetworkManager.game_over_received.is_connected(_on_game_over_received):
		NetworkManager.game_over_received.connect(_on_game_over_received)

	_create_grid()
	_refresh_ui()

func _create_grid():
	for child in grid.get_children():
		child.queue_free()
	tile_buttons.clear()

	for y in range(16):
		for x in range(30):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(32, 32)
			btn.text = ""
			btn.focus_mode = Control.FOCUS_NONE

			var hue = float(x) / 30.0
			var saturation = 0.35 + float(y) / 24.0
			if saturation > 1.0:
				saturation = 1.0

			btn.modulate = Color.from_hsv(hue, saturation, 1.0)
			btn.pressed.connect(_on_tile_pressed.bind(x, y))
			grid.add_child(btn)
			tile_buttons.append(btn)

func _on_tile_pressed(x: int, y: int):
	var is_cue_giver = Session.player_id == Session.cue_giver_id
	if is_cue_giver:
		return
	if not (Session.current_phase == "first_guess" or Session.current_phase == "second_guess"):
		return

	NetworkManager.send_data({
		"type": "select_tile",
		"tileX": x,
		"tileY": y
	})

func _on_send_hint_button_pressed():
	var hint = hint_input.text.strip_edges()
	if hint == "":
		return

	NetworkManager.send_data({
		"type": "submit_hint",
		"hint": hint
	})
	hint_input.text = ""

func _on_secret_tile_received(_data):
	_refresh_ui()

func _on_state_updated(data):
	_refresh_ui()
	_clear_grid_marks()

	for guess in data.get("guesses", []):
		var idx = int(guess.get("y", 0)) * 30 + int(guess.get("x", 0))
		if idx >= 0 and idx < tile_buttons.size():
			tile_buttons[idx].text = guess.get("name", "?").substr(0, 1).to_upper()

func _on_round_result_received(_data):
	get_tree().change_scene_to_file("res://scenes/RoundResult.tscn")

func _on_game_over_received(data):
	var lines = ["Kraj igre"]
	for player in data.get("players", []):
		lines.append("%s: %s" % [player.get("name", "Igrac"), str(player.get("score", 0))])
	info_label.text = "\n".join(lines)

func _refresh_ui():
	round_label.text = "Runda: " + str(Session.current_round)
	phase_label.text = "Faza: " + Session.current_phase
	hint_label.text = "Hint: " + Session.current_hint

	var cue_giver_name = _get_player_name(Session.cue_giver_id)
	cue_giver_label.text = "Cue Giver: " + cue_giver_name

	var is_cue_giver = Session.player_id == Session.cue_giver_id

	if is_cue_giver:
		info_label.text = "Ti si Cue Giver."
	else:
		info_label.text = "Ti pogadjas boju."

	if Session.secret_tile.size() > 0 and is_cue_giver:
		secret_tile_label.text = "Tajno polje: (%s, %s)" % [
			str(Session.secret_tile.get("x", -1)),
			str(Session.secret_tile.get("y", -1))
		]
	else:
		secret_tile_label.text = ""

	var can_send_hint = is_cue_giver and (
		Session.current_phase == "first_hint" or Session.current_phase == "second_hint"
	)

	hint_input.visible = can_send_hint
	hint_input.editable = can_send_hint
	send_hint_button.visible = can_send_hint
	send_hint_button.disabled = not can_send_hint

	_refresh_scores()

func _refresh_scores():
	for child in score_container.get_children():
		child.queue_free()

	for player in Session.players:
		var label := Label.new()
		label.text = "%s: %s" % [player.get("name", "Igrac"), str(player.get("score", 0))]
		score_container.add_child(label)

func _clear_grid_marks():
	for btn in tile_buttons:
		btn.text = ""

func _get_player_name(player_id: String) -> String:
	for player in Session.players:
		if player.get("id", "") == player_id:
			return player.get("name", "Igrac")
	return "?"
