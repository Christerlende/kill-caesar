extends Control

## Lobby UI: host or join, see connected players, start game.

const NetworkManager_path = "res://scripts/network/network_manager.gd"
const GameManager = preload("res://scripts/game/game_manager.gd")

@onready var back_button: Button = $BackButton
@onready var status_label: Label = $CenterContainer/LobbyPanel/Margin/VBox/StatusLabel
@onready var player_list_label: Label = $CenterContainer/LobbyPanel/Margin/VBox/PlayerListLabel
@onready var start_button: Button = $CenterContainer/LobbyPanel/Margin/VBox/StartButton
@onready var waiting_label: Label = $CenterContainer/LobbyPanel/Margin/VBox/WaitingLabel

var _is_host: bool = false

func _ready() -> void:
	var nm = _get_network_manager()
	nm.player_list_changed.connect(_refresh_player_list)
	nm.connection_failed.connect(_on_connection_failed)
	nm.connection_succeeded.connect(_on_connection_succeeded)
	nm.server_disconnected.connect(_on_server_disconnected)
	nm.game_starting.connect(_on_game_starting)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_is_host = nm.is_host()
	start_button.visible = _is_host
	waiting_label.visible = not _is_host
	if _is_host:
		status_label.text = "Hosting on port %d — share your IP with friends" % nm.DEFAULT_PORT
	else:
		status_label.text = "Connecting to host…"
	_refresh_player_list()

func _get_network_manager():
	return get_node("/root/NetworkManager")

func _refresh_player_list() -> void:
	var nm = _get_network_manager()
	var sorted = nm.get_sorted_peer_ids()
	var lines: Array = []
	for i in range(sorted.size()):
		var peer_id = sorted[i]
		var info = nm.players[peer_id]
		var tag = " (you)" if peer_id == nm.get_my_peer_id() else ""
		var host_tag = " [Host]" if peer_id == 1 else ""
		lines.append("Player %d: %s%s%s" % [i + 1, info["name"], host_tag, tag])
	player_list_label.text = "\n".join(lines) if lines.size() > 0 else "No players connected"
	if _is_host:
		var count = nm.get_player_count()
		start_button.disabled = count < 1
		var ai_count = 6 - count
		if ai_count > 0:
			start_button.text = "Start Game (%d player%s + %d AI)" % [count, "" if count == 1 else "s", ai_count]
		else:
			start_button.text = "Start Game (%d players)" % count

func _on_connection_succeeded() -> void:
	status_label.text = "Connected! Waiting for host to start…"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Check the IP and try again."

func _on_server_disconnected() -> void:
	status_label.text = "Host disconnected."
	start_button.visible = false
	waiting_label.text = "Host left the game."
	waiting_label.visible = true

func _on_start_pressed() -> void:
	var nm = _get_network_manager()
	if not nm.is_host():
		return
	nm.assign_seats()
	GameManager.influence_to_win = 7
	nm.start_game.rpc()

func _on_game_starting() -> void:
	var nm = _get_network_manager()
	# Build queued player names from seat order
	var names: Array = []
	var sorted = nm.get_sorted_peer_ids()
	for peer_id in sorted:
		names.append(nm.players[peer_id]["name"])
	# Pad to 6 with AI players
	while names.size() < 6:
		names.append("AI %d" % (names.size() + 1))
	GameManager.queue_player_names(names)
	GameManager.influence_to_win = 7
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_back_pressed() -> void:
	var nm = _get_network_manager()
	nm.disconnect_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
