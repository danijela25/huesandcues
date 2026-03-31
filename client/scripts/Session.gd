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
var correct_tile: Dictionary = {}
var round_scores: Array = []

func reset_game_state():
	secret_tile = {}
	current_round = 1
	current_phase = ""
	current_hint = ""
	cue_giver_id = ""
	correct_tile = {}
	round_scores = []
