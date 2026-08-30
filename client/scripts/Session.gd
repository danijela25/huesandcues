extends Node

const RECONNECT_FILE := "user://reconnect.cfg"

var player_name := ""
var player_id := ""
var room_code := ""
var host_id := ""
var players: Array = []

var secret_tile: Dictionary = {}
var current_round := 1
var current_phase := ""
var current_hint := ""
var cue_giver_id := ""
var current_guesser_id := ""
var current_guesser_name := ""

var correct_tile: Dictionary = {}
var round_scores: Array = []
var next_cue_giver_id := ""
var next_cue_giver_name := ""

var pending_tile_x := -1
var pending_tile_y := -1
var replay_votes: Array = []


func save_reconnect_data():
	if player_id == "" or room_code == "":
		return

	var config := ConfigFile.new()

	config.set_value(
		"session",
		"player_id",
		player_id
	)

	config.set_value(
		"session",
		"room_code",
		room_code
	)

	config.set_value(
		"session",
		"player_name",
		player_name
	)

	config.save(RECONNECT_FILE)


func load_reconnect_data() -> bool:
	var config := ConfigFile.new()

	var err := config.load(RECONNECT_FILE)

	if err != OK:
		return false

	player_id = str(
		config.get_value(
			"session",
			"player_id",
			""
		)
	)

	room_code = str(
		config.get_value(
			"session",
			"room_code",
			""
		)
	)

	player_name = str(
		config.get_value(
			"session",
			"player_name",
			""
		)
	)

	return (
		player_id != ""
		and room_code != ""
	)


func clear_reconnect_data():
	var dir := DirAccess.open("user://")

	if dir == null:
		return

	if dir.file_exists("reconnect.cfg"):
		dir.remove("reconnect.cfg")


func reset_game_state():
	clear_reconnect_data()

	players = []
	player_id = ""
	room_code = ""
	host_id = ""
	player_name = ""
	secret_tile = {}
	current_round = 1
	current_phase = ""
	current_hint = ""
	cue_giver_id = ""
	current_guesser_id = ""
	current_guesser_name = ""
	correct_tile = {}
	round_scores = []
	next_cue_giver_id = ""
	next_cue_giver_name = ""
	pending_tile_x = -1
	pending_tile_y = -1
	replay_votes = []
