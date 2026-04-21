extends Control

const ROW_LETTERS := "ABCDEFGHIJKLMNOP"

@onready var player_name_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/PlayerNameLabel
@onready var round_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundLabel
@onready var phase_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/PhaseLabel
@onready var cue_giver_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/CueGiverLabel
@onready var current_player_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/CurrentPlayerLabel
@onready var hint_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/HintLabel
@onready var card_title_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/CardTitleLabel
@onready var color_card_panel: PanelContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/ColorCardPanel
@onready var secret_tile_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/ColorCardPanel/ColorCardVBox/SecretTileLabel
@onready var color_preview: ColorRect = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/ColorCardPanel/ColorCardVBox/ColorPreview
@onready var hint_input: LineEdit = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/HintInput
@onready var send_hint_button: Button = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/SendHintButton
@onready var selected_tile_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/SelectedTileLabel
@onready var confirm_tile_button: Button = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/ConfirmTileButton
@onready var info_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/InfoLabel
@onready var score_container: VBoxContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/ScoreContainer
@onready var round_result_panel: PanelContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel
@onready var round_correct_tile_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel/RoundResultVBox/RoundCorrectTileLabel
@onready var round_color_preview: ColorRect = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel/RoundResultVBox/RoundColorPreview
@onready var next_cue_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel/RoundResultVBox/NextCueLabel
@onready var round_scores_container: VBoxContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel/RoundResultVBox/RoundScoresContainer
@onready var ready_next_round_button: Button = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/RoundResultPanel/RoundResultVBox/ReadyNextRoundButton
@onready var final_results_panel: PanelContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel
@onready var winner_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel/FinalResultsVBox/WinnerLabel
@onready var final_scores_container: VBoxContainer = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel/FinalResultsVBox/FinalScoresContainer
@onready var replay_status_label: Label = $RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel/FinalResultsVBox/ReplayStatusLabel
@onready var top_numbers: HBoxContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/TopNumbers
@onready var left_letters: VBoxContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/GridRowsArea/LeftLetters
@onready var grid: GridContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/GridRowsArea/GridContainer
@onready var left_panel: PanelContainer = $RootMargin/HBox/LeftPanel
@onready var grid_panel: PanelContainer = $RootMargin/HBox/GridPanel
@onready var right_panel: PanelContainer = $RootMargin/HBox/RightPanel
@onready var room_code_label: Label = $RootMargin/HBox/RightPanel/RightMargin/RightVBox/RoomCodePanel/RoomCodeLabel
@onready var top_banner: PanelContainer = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/TopBanner
@onready var top_banner_label: Label = $RootMargin/HBox/GridPanel/GridMargin/GridLayout/TopBanner/TopBannerLabel
@onready var logo_label: Label = $RootMargin/HBox/RightPanel/RightMargin/RightVBox/LogoLabel
@onready var sidebar_players_container: VBoxContainer = $RootMargin/HBox/RightPanel/RightMargin/RightVBox/SidebarPlayersContainer
@onready var sidebar_info_label: Label = $RootMargin/HBox/RightPanel/RightMargin/RightVBox/SidebarInfoLabel
@onready var click_sound= $AudioStreamPlayer/AudioStreamPlayer
@onready var celebration_sound=$AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer
@onready var tatada_sound=$AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer
@onready var loser_sound=$AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer/AudioStreamPlayer
var tile_buttons: Array = []
var guess_markers: Array = []
var player_index_map = {}
var player_textures = {}

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_load_player_textures()
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

	_apply_global_visual_style()
	_create_board_labels()
	_create_grid()
	_refresh_ui()

func _load_player_textures():
	player_textures[1] = preload("res://assets/players/PlayerBlue.png")
	player_textures[2] = preload("res://assets/players/PlayerGreen.png")
	player_textures[3] = preload("res://assets/players/PlayerOrange.png")
	player_textures[4] = preload("res://assets/players/PlayerPink.png")
	player_textures[5] = preload("res://assets/players/PlayerPurple.png")
	player_textures[6] = preload("res://assets/players/PlayerRed.png")	
func _make_stylebox(color: Color, border_color: Color = Color(0,0,0,0), border_width: int = 0, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border_color
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb

func _player_color(index: int) -> Color:
	var colors = [
		Color("4f6bff"),
		Color("ff9e2c"),
		Color("36e7c2"),
		Color("a05cff"),
		Color("ff5b8f"),
		Color("7fe34f")
	]
	return colors[index % colors.size()]

func _base_tile_color(x: int, y: int) -> Color:
	var hue := (float(x) / 30.0) + (float(y) / 200.0)
	if hue > 1.0:
		hue -= 1.0

	var saturation := 0.35 + float(y) / 22.0
	if saturation > 1.0:
		saturation = 1.0

	var value := 1.0 - float(y) / 26.0
	if value < 0.65:
		value = 0.65

	return Color.from_hsv(hue, saturation, value)
	
func _apply_global_visual_style():
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color("0a0913")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	left_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.10, 0.09, 0.18, 0.98), Color("4f4190"), 1, 18))
	grid_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.06, 0.06, 0.11, 0.98), Color("2d2748"), 1, 18))
	color_card_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.06, 0.06, 0.10, 1.0), Color("2d2d44"), 1, 14))
	round_result_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.09, 0.09, 0.13, 0.98), Color("6a63c7"), 1, 16))
	final_results_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.09, 0.09, 0.13, 0.98), Color("6a63c7"), 1, 16))
	right_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.03, 0.05, 0.99), Color("202036"), 1, 18))
	$RootMargin/HBox/RightPanel/RightMargin/RightVBox/RoomCodePanel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.09, 0.09, 0.13, 1.0), Color("343455"), 1, 10))
	top_banner.add_theme_stylebox_override("panel", _make_stylebox(Color(0.10, 0.10, 0.14, 0.96), Color("3b355e"), 1, 12))

	var input_normal = _make_stylebox(Color(0.10, 0.10, 0.14, 1.0), Color("6d6399"), 1, 10)
	var input_focus = _make_stylebox(Color(0.12, 0.11, 0.18, 1.0), Color("9a81ff"), 2, 10)
	hint_input.add_theme_stylebox_override("normal", input_normal)
	hint_input.add_theme_stylebox_override("focus", input_focus)
	hint_input.add_theme_color_override("font_color", Color.WHITE)
	hint_input.add_theme_color_override("font_placeholder_color", Color(0.68, 0.68, 0.76))

	_style_button(send_hint_button, Color("5b3fb1"), Color("7f5fff"))
	_style_button(confirm_tile_button, Color("2e7dff"), Color("65a0ff"))
	_style_button(ready_next_round_button, Color("24a46d"), Color("4be5a0"))
	_style_button($RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel/FinalResultsVBox/ReplayButton, Color("5b3fb1"), Color("8a63ff"))
	_style_button($RootMargin/HBox/LeftPanel/LeftMargin/LeftVBox/FinalResultsPanel/FinalResultsVBox/ExitButton, Color("1a1a22"), Color("56566f"))

	for lbl in [player_name_label, phase_label, cue_giver_label, current_player_label, hint_label, card_title_label, selected_tile_label, info_label, replay_status_label, room_code_label, sidebar_info_label, $RootMargin/HBox/RightPanel/RightMargin/RightVBox/SidebarPlayersTitle]:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	for lbl in [round_label, winner_label, next_cue_label, top_banner_label]:
		lbl.add_theme_color_override("font_color", Color.WHITE)
	logo_label.add_theme_font_size_override("font_size", 28)
	logo_label.add_theme_color_override("font_color", Color.WHITE)
	room_code_label.add_theme_font_size_override("font_size", 18)
	top_banner_label.add_theme_font_size_override("font_size", 18)

func _style_button(btn: Button, base: Color, border: Color):
	btn.add_theme_stylebox_override("normal", _make_stylebox(base, border, 1, 10))
	btn.add_theme_stylebox_override("hover", _make_stylebox(base.lightened(0.10), border.lightened(0.10), 1, 10))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(base.darkened(0.12), border, 1, 10))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(base.darkened(0.25), border.darkened(0.25), 1, 10))
	btn.add_theme_color_override("font_color", Color.WHITE)

func _create_board_labels():
	for child in top_numbers.get_children():
		child.queue_free()
	for child in left_letters.get_children():
		child.queue_free()

	var tile_w := 33
	var tile_h := 33

	var spacer := Label.new()
	spacer.custom_minimum_size = Vector2(32, tile_h)
	top_numbers.add_child(spacer)

	for x in range(30):
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(tile_w, tile_h)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.text = str(x + 1)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		top_numbers.add_child(lbl)

	for y in range(16):
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(28, tile_h)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text = ROW_LETTERS[y]
		lbl.add_theme_color_override("font_color", Color.WHITE)
		left_letters.add_child(lbl)
func _create_grid():
	for child in grid.get_children():
		child.free()
	grid.columns = 30
	tile_buttons.clear()
	for y in range(16):
		for x in range(30):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(33, 33)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn.text = ""
			btn.focus_mode = Control.FOCUS_NONE
			btn.add_theme_font_size_override("font_size", 9)
			btn.add_theme_color_override("font_color", Color.WHITE)
			_apply_tile_style(btn, x, y)
			btn.pivot_offset = Vector2(16.5, 16.5)
			btn.mouse_entered.connect(_on_tile_mouse_entered.bind(btn))
			btn.mouse_exited.connect(_on_tile_mouse_exited.bind(btn))
			btn.pressed.connect(_on_tile_pressed.bind(x, y))
			grid.add_child(btn)
			tile_buttons.append(btn)

func _apply_tile_style(btn: Button, x: int, y: int):
	var col := _base_tile_color(x, y)
	btn.add_theme_stylebox_override("normal", _make_stylebox(col, Color(0.02,0.02,0.05,0.4), 1, 2))
	btn.add_theme_stylebox_override("hover", _make_stylebox(col.lightened(0.08), Color(1,1,1,0.25), 1, 2))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(col.darkened(0.08), Color(1,1,1,0.18), 1, 2))
	btn.add_theme_stylebox_override("focus", _make_stylebox(col, Color(1,1,1,0.18), 1, 2))
	btn.add_theme_stylebox_override("disabled", _make_stylebox(col.darkened(0.1), Color(0.02,0.02,0.05,0.4), 1, 2))

func _tile_code(x: int, y: int) -> String:
	return ROW_LETTERS[y] + str(x + 1)

func _reset_all_tile_styles():
	for y in range(16):
		for x in range(30):
			var idx := y * 30 + x
			if idx >= 0 and idx < tile_buttons.size():
				_apply_tile_style(tile_buttons[idx], x, y)
				for child in tile_buttons[idx].get_children():
					child.queue_free()

func _marker_symbol(index: int) -> String:
	var symbols := ["1", "2", "3", "4", "5", "6"]
	return symbols[index] if index < symbols.size() else str(index + 1)

func _store_guess_markers(guesses):
	if guesses.size() == 0:
		return
	guess_markers = []
	for g in guesses:
		var idx = player_index_map.get(g.playerId, 1)
		guess_markers.append({
				"x": int(g.get("x", 0)),
				"y": int(g.get("y", 0)),
				"symbol": str(idx) + ("²" if g.get("type") == "second" else "¹"),
				"color": _player_color(idx - 1),
				"type": g.get("type")
		
		})	
		print("GUESS DATA:", guesses)	

func _aggregate_tile_symbols() -> Dictionary:
	var tile_map := {}
	for marker in guess_markers:
		var key := "%s_%s" % [str(marker["x"]), str(marker["y"])]
		if not tile_map.has(key):
			tile_map[key] = []
		tile_map[key].append(marker)
	return tile_map

func _clear_avatar_markers():
	for btn in tile_buttons:
		for child in btn.get_children():
			if child is Sprite2D:
				child.queue_free()
				
func _draw_badge(parent: Control, symbol: String, color: Color, idx: int):
	var player_num_text := symbol.substr(0, symbol.length() - 1)
	var player_num := int(player_num_text)

	var sprite := Sprite2D.new()
	sprite.texture = player_textures.get(player_num, null)
	if sprite.texture == null:
		return

	sprite.centered = true

	var tex_size = sprite.texture.get_size()
	var target_size := Vector2(38, 38)
	var scale_x = target_size.x / tex_size.x
	var scale_y = target_size.y / tex_size.y
	sprite.scale = Vector2(scale_x, scale_y)

	if idx == 0:
		sprite.position = Vector2(12, 12)
	elif idx == 1:
		sprite.position = Vector2(28, 28)
	elif idx == 2:
		sprite.position = Vector2(28, 12)
	else:
		sprite.position = Vector2(12, 28)
	parent.add_child(sprite)
func _draw_guess_markers():
	_clear_avatar_markers()

	var tile_map = _aggregate_tile_symbols()
	for key in tile_map.keys():
		var parts = key.split("_")
		var x = int(parts[0])
		var y = int(parts[1])
		var idx = y * 30 + x

		if idx >= 0 and idx < tile_buttons.size():
			var btn: Button = tile_buttons[idx]
			var markers: Array = tile_map[key]

			for i in range(markers.size()):
				_draw_badge(btn, str(markers[i]["symbol"]), markers[i]["color"], i)
func _clear_pending_marker():
	for btn in tile_buttons:
		for child in btn.get_children():
			if child is Label and child.text == "?":
				child.queue_free()

func _clear_grid_texts_only():
	for btn in tile_buttons:
		btn.text = ""
		for child in btn.get_children():
			if child is Label:
				child.queue_free()
	_draw_guess_markers()

func _draw_correct_tile_matrix():
	tatada_sound.play()
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
				btn.add_theme_stylebox_override("normal", _make_stylebox(col, Color("dcd8ff"), 2, 2))
	var center_idx := cy * 30 + cx
	if center_idx >= 0 and center_idx < tile_buttons.size():
		var center_btn: Button = tile_buttons[center_idx]
		var center_col := _base_tile_color(cx, cy)
		center_btn.add_theme_stylebox_override("normal", _make_stylebox(center_col, Color("ffffff"), 4, 2))
	_draw_guess_markers()


func _animate_tile(btn: Button, target_scale: Vector2, duration: float = 0.08):
	var tween = create_tween()
	tween.tween_property(btn, "scale", target_scale, duration)

func _on_tile_mouse_entered(btn: Button):
	_animate_tile(btn, Vector2(1.06, 1.06), 0.08)

func _on_tile_mouse_exited(btn: Button):
	_animate_tile(btn, Vector2.ONE, 0.08)

func _pulse_scores():
	for child in score_container.get_children():
		child.scale = Vector2.ONE
		var tween = create_tween()
		tween.tween_property(child, "scale", Vector2(1.03, 1.03), 0.08)
		tween.tween_property(child, "scale", Vector2.ONE, 0.08)

func _flash_correct_area():
	if Session.correct_tile.is_empty():
		return
	var cx := int(Session.correct_tile.get("x", -1))
	var cy := int(Session.correct_tile.get("y", -1))
	for y in range(max(0, cy - 1), min(15, cy + 1) + 1):
		for x in range(max(0, cx - 1), min(29, cx + 1) + 1):
			var idx := y * 30 + x
			if idx >= 0 and idx < tile_buttons.size():
				var btn = tile_buttons[idx]
				btn.modulate = Color(1.0, 1.0, 1.0, 0.75)
				var tween = create_tween()
				tween.tween_property(btn, "modulate", Color.WHITE, 0.22)

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
	_clear_grid_texts_only()
	var idx := y * 30 + x
	if idx >= 0 and idx < tile_buttons.size():
		var mark := Label.new()
		mark.text = "?"
		mark.position = Vector2(9, 6)
		mark.add_theme_color_override("font_color", Color.WHITE)
		tile_buttons[idx].add_child(mark)

func _on_confirm_tile_button_pressed():
	if Session.pending_tile_x < 0 or Session.pending_tile_y < 0:
		return
	NetworkManager.send_data({"type": "select_tile", "tileX": Session.pending_tile_x, "tileY": Session.pending_tile_y})
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
	guess_markers.clear()
	_clear_avatar_markers()
	NetworkManager.send_data({"type": "next_round_ready"})
func _on_replay_button_pressed():
	NetworkManager.send_data({"type": "restart_game_vote"})

func _on_exit_button_pressed():
	guess_markers.clear()
	_clear_avatar_markers()
	Session.reset_game_state()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
func _on_secret_tile_received(_data):
	_refresh_ui()

func _on_state_updated(data):
	#_reset_all_tile_styles()
	round_result_panel.visible = false
	_refresh_ui()
	if data.has("guesses"):
		_store_guess_markers(data.get("guesses", []))
		_draw_guess_markers()
	#_clear_grid_texts_only()

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
		label.add_theme_color_override("font_color", Color.WHITE)
		round_scores_container.add_child(label)
	ready_next_round_button.visible = Session.player_id == Session.next_cue_giver_id
	ready_next_round_button.disabled = false

func _update_replay_status():
	replay_status_label.text = "Potvrde za novu partiju: %s/%s" % [str(Session.replay_votes.size()), str(Session.players.size())]

func _on_round_result_received(_data):
	#_reset_all_tile_styles()
	#_clear_grid_texts_only()
	_draw_correct_tile_matrix()
	_flash_correct_area()
	_pulse_scores()
	_show_round_result_inline()

func _on_game_over_received(data):
	#_reset_all_tile_styles()
	#_clear_grid_texts_only()
	_clear_avatar_markers()
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
	for i in range(players.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chip := Label.new()
		chip.text = str(i + 1)
		chip.custom_minimum_size = Vector2(22, 22)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_color_override("font_color", Color.WHITE)
		chip.add_theme_stylebox_override("normal", _make_stylebox(_player_color(i), Color.WHITE, 1, 999))
		var txt := Label.new()
		txt.text = "%s: %s" % [players[i].get("name", "Igrač"), str(players[i].get("score", 0))]
		txt.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(chip)
		row.add_child(txt)
		final_scores_container.add_child(row)
	_update_replay_status()
	_draw_guess_markers()

func _on_error_received(message):
	info_label.text = message

func _refresh_ui():
	player_name_label.text = "Ti si: " + Session.player_name
	player_index_map.clear()
	for i in range(Session.players.size()):
		var p=Session.players[i]
		player_index_map[p.id]=i+1
	round_label.text = "Runda: " + str(Session.current_round)
	phase_label.text = "Faza: " + Session.current_phase
	hint_label.text = "Hint: " + Session.current_hint
	var cue_name = _get_player_name(Session.cue_giver_id)
	cue_giver_label.text = "Cue Giver: " + cue_name
	current_player_label.text = "Na potezu: " + (Session.current_guesser_name if Session.current_guesser_name != "" else "-")
	top_banner_label.text = "CUE GIVER: " + cue_name + "   |   Hint: " + (Session.current_hint if Session.current_hint != "" else "-")

	var is_cue_giver := Session.player_id == Session.cue_giver_id
	if is_cue_giver:
		info_label.text = "Ti si Cue Giver. Zadaj hint." if Session.current_phase == "Prvi hint" or Session.current_phase == "Drugi hint" else "Sačekaj da ostali odigraju."
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
	_refresh_sidebar_players()
	_update_replay_status()


func _refresh_sidebar_players():
	for child in sidebar_players_container.get_children():
		child.queue_free()

	room_code_label.text = "ROOM CODE: " + (Session.room_code if Session.room_code != "" else "-")

	for i in range(Session.players.size()):
		var player = Session.players[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var chip := TextureRect.new()
		chip.custom_minimum_size = Vector2(28, 28)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.texture = player_textures.get(i + 1, null)

		var txt := Label.new()
		var suffix = " (you)" if player.get("id", "") == Session.player_id else ""
		txt.text = "%s%s" % [player.get("name", "Igrač"), suffix]
		txt.add_theme_color_override("font_color", Color.WHITE)

		var wrap := PanelContainer.new()
		wrap.add_theme_stylebox_override("panel", _make_stylebox(Color(0.08, 0.08, 0.12, 1.0), Color("2e2e48"), 1, 10))

		var inner := MarginContainer.new()
		inner.add_theme_constant_override("margin_left", 8)
		inner.add_theme_constant_override("margin_top", 6)
		inner.add_theme_constant_override("margin_right", 8)
		inner.add_theme_constant_override("margin_bottom", 6)

		wrap.add_child(inner)
		inner.add_child(row)

		row.add_child(chip)
		row.add_child(txt)
		sidebar_players_container.add_child(wrap)	
func _refresh_scores():
	for child in score_container.get_children():
		child.queue_free()

	for i in range(Session.players.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var chip := TextureRect.new()
		chip.custom_minimum_size = Vector2(22, 22)
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.texture = player_textures.get(i + 1, null)

		var txt := Label.new()
		txt.text = "%s  %s" % [Session.players[i].get("name", "Igrač"), str(Session.players[i].get("score", 0))]
		txt.add_theme_color_override("font_color", Color.WHITE)

		var wrap := PanelContainer.new()
		wrap.add_theme_stylebox_override("panel", _make_stylebox(Color(0.08, 0.08, 0.13, 1.0), Color("2c2850"), 1, 10))

		var inner := MarginContainer.new()
		inner.add_theme_constant_override("margin_left", 8)
		inner.add_theme_constant_override("margin_top", 4)
		inner.add_theme_constant_override("margin_right", 8)
		inner.add_theme_constant_override("margin_bottom", 4)

		wrap.add_child(inner)
		inner.add_child(row)
		row.add_child(chip)
		row.add_child(txt)
		score_container.add_child(wrap)
func _get_player_name(player_id: String) -> String:
	for player in Session.players:
		if player.get("id", "") == player_id:
			return player.get("name", "Igrač")
	return "?"
