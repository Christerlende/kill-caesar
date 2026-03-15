extends Control

const GameManager = preload("res://scripts/game/game_manager.gd")

@onready var winner_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/WinnerLabel
@onready var summary_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SummaryLabel
@onready var play_again_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/MainMenuButton

func _ready() -> void:
	winner_label.text = "%s Win!" % GameManager.last_winner_text
	summary_label.text = "Round: %d\nPatrician Influence: %d\nPlebeian Influence: %d" % [
		GameManager.last_round_number,
		GameManager.last_patrician_influence,
		GameManager.last_plebian_influence
	]
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)

func _on_play_again_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
