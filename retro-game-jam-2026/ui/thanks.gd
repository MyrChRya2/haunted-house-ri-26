extends Control

@onready var replay: Button = $VBoxContainer/Button
@export var level_scene: PackedScene

func _ready() -> void:
	replay.pressed.connect(_on_game_start_pressed)

func _on_game_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level/title/title.tscn")
func _on_exit_pressed() -> void:
	get_tree().quit()
