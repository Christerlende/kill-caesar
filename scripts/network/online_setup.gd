extends Control

## Pre-lobby screen: enter name, choose host or join, then go to lobby.

@onready var back_button: Button = $BackButton
@onready var name_input: LineEdit = $CenterContainer/SetupPanel/Margin/VBox/NameInput
@onready var host_button: Button = $CenterContainer/SetupPanel/Margin/VBox/HostButton
@onready var ip_input: LineEdit = $CenterContainer/SetupPanel/Margin/VBox/IPInput
@onready var port_input: LineEdit = $CenterContainer/SetupPanel/Margin/VBox/PortInput
@onready var join_button: Button = $CenterContainer/SetupPanel/Margin/VBox/JoinButton
@onready var feedback_label: Label = $CenterContainer/SetupPanel/Margin/VBox/FeedbackLabel

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	feedback_label.text = ""
	name_input.grab_focus()

func _get_network_manager():
	return get_node("/root/NetworkManager")

func _get_port() -> int:
	var text = port_input.text.strip_edges()
	if text == "":
		return 7000
	var val = int(text)
	if val < 1 or val > 65535:
		return 7000
	return val

func _validate_name() -> String:
	var n = name_input.text.strip_edges()
	if n == "":
		feedback_label.text = "Please enter a name."
		return ""
	return n

func _on_host_pressed() -> void:
	var player_name = _validate_name()
	if player_name == "":
		return
	var nm = _get_network_manager()
	var port = _get_port()
	var err = nm.host_game(player_name, port)
	if err != OK:
		feedback_label.text = "Failed to host on port %d. Is it already in use?" % port
		return
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

func _on_join_pressed() -> void:
	var player_name = _validate_name()
	if player_name == "":
		return
	var address = ip_input.text.strip_edges()
	if address == "":
		feedback_label.text = "Please enter the host IP address."
		return
	var nm = _get_network_manager()
	var port = _get_port()
	var err = nm.join_game(player_name, address, port)
	if err != OK:
		feedback_label.text = "Failed to connect to %s:%d." % [address, port]
		return
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
