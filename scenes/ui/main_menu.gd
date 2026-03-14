extends Control

signal start_game_pressed

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	start_game_pressed.emit()
	get_tree().change_scene_to_file("res://scenes/game.tscn")
