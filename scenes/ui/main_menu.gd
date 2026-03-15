extends Control

signal start_game_pressed
const GameManager = preload("res://scripts/game/game_manager.gd")

@onready var play_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/PlayButton
@onready var test_match_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/TestMatchButton
@onready var rules_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/RulesButton
@onready var quit_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var rules_popup: PanelContainer = $RulesPopup
@onready var close_rules_button: Button = $RulesPopup/PopupMargin/PopupVBox/CloseRulesButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	test_match_button.pressed.connect(_on_test_match_button_pressed)
	rules_button.pressed.connect(_on_rules_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	close_rules_button.pressed.connect(_on_close_rules_button_pressed)
	rules_popup.visible = false

func _on_play_button_pressed() -> void:
	GameManager.influence_to_win = 5
	start_game_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_test_match_button_pressed() -> void:
	print("Starting test match")
	GameManager.influence_to_win = 2
	start_game_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_rules_button_pressed() -> void:
	rules_popup.visible = true

func _on_close_rules_button_pressed() -> void:
	rules_popup.visible = false

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and rules_popup.visible:
		rules_popup.visible = false
