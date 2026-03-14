extends Control

signal start_game_pressed

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	print("Start Game pressed")
	start_game_pressed.emit()
