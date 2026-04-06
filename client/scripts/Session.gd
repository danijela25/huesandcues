extends Node

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

func reset_game_state():
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