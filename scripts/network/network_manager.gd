extends Node

## Autoloaded singleton that owns the ENet multiplayer peer and the
## lobby-level bookkeeping (who is connected, what name they chose,
## which seat they occupy).  Game-logic RPCs live on GameManager;
## NetworkManager only handles connection lifecycle + lobby state.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal player_list_changed
signal connection_failed
signal connection_succeeded
signal server_disconnected
signal game_starting

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 6

## peer_id → { "name": String, "seat": int (-1 = unassigned) }
var players: Dictionary = {}
var my_name: String = "Player"
var is_online: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ── Host / Join ──────────────────────────────────────────────────

func host_game(player_name: String, port: int = DEFAULT_PORT) -> Error:
	my_name = player_name
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("Failed to create server: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_online = true
	_register_player(1, player_name)
	print("Hosting on port %d as '%s'" % [port, player_name])
	return OK

func join_game(player_name: String, address: String, port: int = DEFAULT_PORT) -> Error:
	my_name = player_name
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("Failed to create client: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_online = true
	print("Joining %s:%d as '%s'" % [address, port, player_name])
	return OK

func disconnect_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	players.clear()
	is_online = false
	print("Disconnected from game")

func is_host() -> bool:
	return multiplayer.is_server()

func get_my_peer_id() -> int:
	if not multiplayer.multiplayer_peer:
		return 0
	return multiplayer.get_unique_id()

func get_player_count() -> int:
	return players.size()

func get_sorted_peer_ids() -> Array:
	var ids = players.keys()
	ids.sort()
	return ids

# ── Seat assignment (host only) ────────────────────────────────

func assign_seats() -> void:
	if not is_host():
		return
	var sorted = get_sorted_peer_ids()
	for i in range(sorted.size()):
		players[sorted[i]]["seat"] = i
	_sync_player_list_to_all.rpc(players)

# ── Internal registration ─────────────────────────────────────

func _register_player(peer_id: int, player_name: String) -> void:
	players[peer_id] = { "name": player_name, "seat": -1 }
	player_list_changed.emit()

func _unregister_player(peer_id: int) -> void:
	players.erase(peer_id)
	player_list_changed.emit()

# ── Multiplayer callbacks ─────────────────────────────────────

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: %d" % peer_id)
	player_connected.emit(peer_id)
	# If we are the server, tell the new peer about ourselves
	if is_host():
		# Tell the newcomer about every existing player
		_sync_player_list_to_all.rpc(players)
	# Every peer sends its name to the server
	_register_player_on_server.rpc_id(1, my_name)

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: %d" % peer_id)
	_unregister_player(peer_id)
	player_disconnected.emit(peer_id)
	if is_host():
		_sync_player_list_to_all.rpc(players)

func _on_connected_to_server() -> void:
	print("Connected to server (my id: %d)" % multiplayer.get_unique_id())
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("Connection failed")
	is_online = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("Server disconnected")
	is_online = false
	players.clear()
	player_list_changed.emit()
	server_disconnected.emit()

# ── RPCs ──────────────────────────────────────────────────────

@rpc("any_peer", "reliable")
func _register_player_on_server(player_name: String) -> void:
	var sender = multiplayer.get_remote_sender_id()
	_register_player(sender, player_name)
	# Broadcast updated list to everyone
	_sync_player_list_to_all.rpc(players)

@rpc("authority", "reliable", "call_local")
func _sync_player_list_to_all(player_data: Dictionary) -> void:
	players = player_data
	player_list_changed.emit()

@rpc("authority", "reliable", "call_local")
func start_game() -> void:
	game_starting.emit()
