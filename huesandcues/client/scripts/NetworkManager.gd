extends Node

signal connected
signal disconnected
signal room_created(data)
signal lobby_updated(data)
signal game_started(data)
signal secret_tile_received(data)
signal hint_received(data)
signal tile_selected(data)
signal error_received(message)

var socket := WebSocketPeer.new()
var connected_flag := false
var server_url := "ws://127.0.0.1:3000"

func _process(_delta):
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and not is_connected:
		connected_flag = true
		connected.emit()

	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED and is_connected:
		connected_flag = false
		disconnected.emit()

	while socket.get_available_packet_count() > 0:
		var raw := socket.get_packet().get_string_from_utf8()
		var data = JSON.parse_string(raw)
		if typeof(data) == TYPE_DICTIONARY:
			_handle_message(data)

func connect_to_server():
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		return
	var err := socket.connect_to_url(server_url)
	if err != OK:
		push_error("Ne mogu da se povezem na server")

func send_data(data: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

func _handle_message(data: Dictionary):
	match data.get("type", ""):
		"room_created":
			Session.room_code = data.get("roomCode", "")
			Session.player_id = data.get("playerId", "")
			room_created.emit(data)
		"lobby_state":
			Session.room_code = data.get("roomCode", "")
			Session.host_id = data.get("hostId", "")
			Session.players = data.get("players", [])
			lobby_updated.emit(data)
		"game_start":
			Session.players = data.get("players", [])
			game_started.emit(data)
		"secret_tile":
			Session.secret_tile = {"x": data.get("tileX", -1), "y": data.get("tileY", -1)}
			secret_tile_received.emit(data)
		"new_hint":
			hint_received.emit(data)
		"tile_selected":
			tile_selected.emit(data)
		"error":
			error_received.emit(data.get("message", "Greska"))
