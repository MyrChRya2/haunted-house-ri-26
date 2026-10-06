extends Control

@onready var gamestart: Button = $VBoxContainer/Button
@onready var exit: Button = $VBoxContainer/Button2
@export var level_scene: PackedScene

func _ready() -> void:
	gamestart.pressed.connect(_on_game_start_pressed)
	exit.pressed.connect(_on_exit_pressed)

func _on_game_start_pressed() -> void:
	MapTravel.clear()
	if level_scene:
		get_tree().change_scene_to_packed(level_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/leve1/level1.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
