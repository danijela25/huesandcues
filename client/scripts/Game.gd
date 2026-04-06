extends Control

const ROW_LETTERS := "ABCDEFGHIJKLMNOP"

@onready var player_name_label: Label = $RootMargin/HBox/LeftPanel/PlayerNameLabel
@onready var round_label: Label = $RootMargin/HBox/LeftPanel/RoundLabel
@onready var phase_label: Label = $RootMargin/HBox/LeftPanel/PhaseLabel
@onready var cue_giver_label: Label = $RootMargin/HBox/LeftPanel/CueGiverLabel
@onready var current_player_label: Label = $RootMargin/HBox/LeftPanel/CurrentPlayerLabel
@onready var hint_label: Label = $RootMargin/HBox/LeftPanel/HintLabel
@onready var card_title_label: Label = $RootMargin/HBox/LeftPanel/CardTitleLabel
@onready var color_card_panel: PanelContainer = $RootMargin/HBox/LeftPanel/ColorCardPanel
@onready var secret_tile_label: Label = $RootMargin/HBox/LeftPanel/ColorCardPanel/ColorCardVBox/SecretTileLabel
@onready var color_preview: ColorRect = $RootMargin/HBox/LeftPanel/ColorCardPanel/ColorCardVBox/ColorPreview
@onready var hint_input: LineEdit = $RootMargin/HBox/LeftPanel/HintInput
@onready var send_hint_button: Button = $RootMargin/HBox/LeftPanel/SendHintButton
@onready var selected_tile_label: Label = $RootMargin/HBox/LeftPanel/SelectedTileLabel
@onready var confirm_tile_button: Button = $RootMargin/HBox/LeftPanel/ConfirmTileButton
@onready var info_label: Label = $RootMargin/HBox/LeftPanel/InfoLabel
@onready var score_container: VBoxContainer = $RootMargin/HBox/LeftPanel/ScoreContainer

@onready var round_result_panel: PanelContainer = $RootMargin/HBox/LeftPanel/RoundResultPanel
@onready var round_correct_tile_label: Label = $RootMargin/HBox/LeftPanel/RoundResultPanel/RoundResultVBox/RoundCorrectTileLabel
@onready var round_color_preview: ColorRect = $RootMargin/HBox/LeftPanel/RoundResultPanel/RoundResultVBox/RoundColorPreview
@onready var next_cue_label: Label = $RootMargin/HBox/LeftPanel/RoundResultPanel/RoundResultVBox/NextCueLabel
@onready var round_scores_container: VBoxContainer = $RootMargin/HBox/LeftPanel/RoundResultPanel/RoundResultVBox/RoundScoresContainer
@onready var ready_next_round_button: Button = $RootMargin/HBox/LeftPanel/RoundResultPanel/RoundResultVBox/ReadyNextRoundButton

@onready var final_results_panel: PanelContainer = $RootMargin/HBox/LeftPanel/FinalResultsPanel
@onready var winner_label: Label = $RootMargin/HBox/LeftPanel/FinalResultsPanel/FinalResultsVBox/WinnerLabel
@onready var final_scores_container: VBoxContainer = $RootMargin/HBox/LeftPanel/FinalResultsPanel/FinalResultsVBox/FinalScoresContainer

@onready var top_numbers: HBoxContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/TopNumbers
@onready var left_letters: VBoxContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/GridRowsArea/LeftLetters
@onready var grid: GridContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/GridRowsArea/GridContainer

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
	if not NetworkManager.error_received.is_connected(_on_error_received):
		NetworkManager.error_received.connect(_on_error_received)

	_create_board_labels()
	_create_grid()
	_refresh_ui()

func _make_stylebox(color: Color, border_color: Color = Color(0,0,0,0), border_width: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border_color
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	return sb

func _base_tile_color(x: int, y: int) -> Color:
	var hue = float(x) / 30.0
	var saturation = 0.95
	var value = 1.0 - (float(y) / 40.0)
	if value < 0.72:
		value = 0.72
	return Color.from_hsv(hue, saturation, value)

func _apply_tile_style(btn: Button, x: int, y: int):
	var col := _base_tile_color(x, y)
	btn.add_theme_stylebox_override("normal", _make_stylebox(col))
	btn.add_theme_stylebox_override("hover", _make_stylebox(col.lightened(0.08)))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(col.darkened(0.08)))
	btn.add_theme_stylebox_override("focus", _make_stylebox(col))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(col.darkened(0.1)))

func _create_board_labels():
	for child in top_numbers.get_children():
		child.queue_free()
	for child in left_letters.get_children():
		child.queue_free()
	var spacer := Label.new()
	spacer.custom_minimum_size = Vector2(28, 20)
	top_numbers.add_child(spacer)
	for x in range(30):
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(32, 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = str(x + 1)
		top_numbers.add_child(lbl)
	for y in range(16):
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(28, 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = ROW_LETTERS[y]
		left_letters.add_child(lbl)

func _tile_code(x: int, y: int) -> String:
	return ROW_LETTERS[y] + str(x + 1)

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
			_apply_tile_style(btn, x, y)
			btn.pressed.connect(_on_tile_pressed.bind(x, y))
			grid.add_child(btn)
			tile_buttons.append(btn)

func _reset_all_tile_styles():
	for y in range(16):
		for x in range(30):
			var idx := y * 30 + x
			if idx >= 0 and idx < tile_buttons.size():
				_apply_tile_style(tile_buttons[idx], x, y)

func _clear_pending_marker():
	for btn in tile_buttons:
		if btn.text == "?":
			btn.text = ""

func _clear_grid_marks():
	for btn in tile_buttons:
		btn.text = ""

func _highlight_pending_selection():
	_clear_pending_marker()
	if Session.pending_tile_x >= 0 and Session.pending_tile_y >= 0:
		var idx := Session.pending_tile_y * 30 + Session.pending_tile_x
		if idx >= 0 and idx < tile_buttons.size():
			tile_buttons[idx].text = "?"

func _draw_correct_tile_matrix():
	if Session.correct_tile.is_empty():
		return
	var cx := int(Session.correct_tile.get("x", -1))
	var cy := int(Session.correct_tile.get("y", -1))
	for y in range(max(0, cy - 1), min(15, cy + 1) + 1):
		for x in range(max(0, cx - 1), min(29, cx + 1) + 1):
			var idx := y * 30 + x
			if idx >= 0 and idx < tile_buttons.size():
				var btn: Button = tile_buttons[idx]
				var col := _base_tile_color(x, y)
				btn.add_theme_stylebox_override("normal", _make_stylebox(col, Color(1,1,1,1), 2))
				btn.add_theme_stylebox_override("hover", _make_stylebox(col.lightened(0.08), Color(1,1,1,1), 2))
				btn.add_theme_stylebox_override("pressed", _make_stylebox(col.darkened(0.08), Color(1,1,1,1), 2))
	var center_idx := cy * 30 + cx
	if center_idx >= 0 and center_idx < tile_buttons.size():
		var center_btn: Button = tile_buttons[center_idx]
		var center_col := _base_tile_color(cx, cy)
		center_btn.add_theme_stylebox_override("normal", _make_stylebox(center_col, Color(0,0,0,1), 4))
		center_btn.add_theme_stylebox_override("hover", _make_stylebox(center_col.lightened(0.08), Color(0,0,0,1), 4))
		center_btn.add_theme_stylebox_override("pressed", _make_stylebox(center_col.darkened(0.08), Color(0,0,0,1), 4))

func _on_tile_pressed(x: int, y: int):
	var is_cue_giver := Session.player_id == Session.cue_giver_id
	if is_cue_giver:
		return
	if not (Session.current_phase == "Prvo pogađanje" or Session.current_phase == "Drugo pogađanje"):
		return
	if Session.current_guesser_id != "" and Session.current_guesser_id != Session.player_id:
		return
	Session.pending_tile_x = x
	Session.pending_tile_y = y
	selected_tile_label.text = "Izabrano polje: " + _tile_code(x, y)
	confirm_tile_button.visible = true
	_highlight_pending_selection()

func _on_confirm_tile_button_pressed():
	if Session.pending_tile_x < 0 or Session.pending_tile_y < 0:
		return
	NetworkManager.send_data({
		"type": "select_tile",
		"tileX": Session.pending_tile_x,
		"tileY": Session.pending_tile_y
	})
	_clear_pending_marker()
	Session.pending_tile_x = -1
	Session.pending_tile_y = -1
	selected_tile_label.text = ""
	confirm_tile_button.visible = false

func _on_send_hint_button_pressed():
	var hint := hint_input.text.strip_edges()
	if hint == "":
		return
	NetworkManager.send_data({"type": "submit_hint", "hint": hint})
	hint_input.text = ""

func _on_ready_next_round_button_pressed():
	ready_next_round_button.disabled = true
	round_result_panel.visible = false
	NetworkManager.send_data({"type": "next_round_ready"})

func _on_replay_button_pressed():
	NetworkManager.send_data({"type": "restart_game"})

func _on_exit_button_pressed():
	Session.reset_game_state()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_secret_tile_received(_data):
	_refresh_ui()

func _on_state_updated(data):
	_reset_all_tile_styles()
	round_result_panel.visible = false
	final_results_panel.visible = false
	_refresh_ui()
	_clear_grid_marks()
	_clear_pending_marker()
	for guess in data.get("guesses", []):
		var idx := int(guess.get("y", 0)) * 30 + int(guess.get("x", 0))
		if idx >= 0 and idx < tile_buttons.size():
			tile_buttons[idx].text = guess.get("name", "?").substr(0, 1).to_upper()

func _on_round_result_received(_data):
	_reset_all_tile_styles()
	_clear_grid_marks()
	_draw_correct_tile_matrix()
	_show_round_result_inline()

func _show_round_result_inline():
	round_result_panel.visible = true
	final_results_panel.visible = false
	round_correct_tile_label.text = "Tačna kartica: %s" % str(Session.correct_tile.get("code", ""))
	var c = Session.correct_tile.get("color", {"r": 1.0, "g": 1.0, "b": 1.0})
	round_color_preview.color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), 1.0)
	next_cue_label.text = "Sledeći Cue Giver: " + Session.next_cue_giver_name
	for child in round_scores_container.get_children():
		child.queue_free()
	for item in Session.round_scores:
		var label := Label.new()
		label.text = "%s +%s" % [item.get("name", "Igrač"), str(item.get("delta", 0))]
		round_scores_container.add_child(label)
	ready_next_round_button.visible = Session.player_id == Session.next_cue_giver_id
	ready_next_round_button.disabled = false

func _on_game_over_received(data):
	_reset_all_tile_styles()
	_clear_grid_marks()
	_draw_correct_tile_matrix()
	round_result_panel.visible = false
	final_results_panel.visible = true
	var players = data.get("players", [])
	if players.size() > 0:
		var top_score = players[0].get("score", 0)
		var winners = []
		for p in players:
			if p.get("score", 0) == top_score:
				winners.append(p.get("name", "Igrač"))
		winner_label.text = "Pobednik: " + ", ".join(winners)
	else:
		winner_label.text = "Pobednik: -"
	for child in final_scores_container.get_children():
		child.queue_free()
	for p in players:
		var label := Label.new()
		label.text = "%s: %s" % [p.get("name", "Igrač"), str(p.get("score", 0))]
		final_scores_container.add_child(label)

func _on_error_received(message):
	info_label.text = message

func _refresh_ui():
	player_name_label.text = "Ti si: " + Session.player_name
	round_label.text = "Runda: " + str(Session.current_round)
	phase_label.text = "Faza: " + Session.current_phase
	hint_label.text = "Hint: " + Session.current_hint
	cue_giver_label.text = "Cue Giver: " + _get_player_name(Session.cue_giver_id)
	current_player_label.text = "Na potezu: " + (Session.current_guesser_name if Session.current_guesser_name != "" else "-")

	var is_cue_giver := Session.player_id == Session.cue_giver_id
	if is_cue_giver:
		if Session.current_phase == "Prvi hint" or Session.current_phase == "Drugi hint":
			info_label.text = "Ti si Cue Giver. Zadaj hint."
		else:
			info_label.text = "Sačekaj da ostali odigraju."
	else:
		if Session.current_guesser_id == Session.player_id and (Session.current_phase == "Prvo pogađanje" or Session.current_phase == "Drugo pogađanje"):
			info_label.text = "Ti si na potezu."
		elif Session.current_phase == "Prvo pogađanje" or Session.current_phase == "Drugo pogađanje":
			info_label.text = "Čekaj red."
		else:
			info_label.text = "Čekaj hint."

	if Session.secret_tile.size() > 0 and is_cue_giver:
		card_title_label.visible = true
		color_card_panel.visible = true
		secret_tile_label.text = "Kartica: " + str(Session.secret_tile.get("code", ""))
		var c = Session.secret_tile.get("color", {"r": 1.0, "g": 1.0, "b": 1.0})
		color_preview.color = Color(float(c.get("r", 1.0)), float(c.get("g", 1.0)), float(c.get("b", 1.0)), 1.0)
	else:
		card_title_label.visible = false
		color_card_panel.visible = false
		secret_tile_label.text = ""

	var can_send_hint := is_cue_giver and (Session.current_phase == "Prvi hint" or Session.current_phase == "Drugi hint")
	hint_input.visible = can_send_hint
	hint_input.editable = can_send_hint
	send_hint_button.visible = can_send_hint
	send_hint_button.disabled = not can_send_hint

	var my_turn := Session.current_guesser_id == Session.player_id and (Session.current_phase == "Prvo pogađanje" or Session.current_phase == "Drugo pogađanje")
	confirm_tile_button.visible = my_turn and Session.pending_tile_x >= 0 and Session.pending_tile_y >= 0
	if not my_turn:
		selected_tile_label.text = ""
		Session.pending_tile_x = -1
		Session.pending_tile_y = -1

	_refresh_scores()

func _refresh_scores():
	for child in score_container.get_children():
		child.queue_free()
	for player in Session.players:
		var label := Label.new()
		label.text = "%s: %s" % [player.get("name", "Igrač"), str(player.get("score", 0))]
		score_container.add_child(label)

func _get_player_name(player_id: String) -> String:
	for player in Session.players:
		if player.get("id", "") == player_id:
			return player.get("name", "Igrač")
	return "?"