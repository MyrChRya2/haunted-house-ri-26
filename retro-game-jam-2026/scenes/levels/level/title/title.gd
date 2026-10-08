extends Control

@onready var white_shot: Sprite2D = $WhiteShot
@onready var title: AnimatedSprite2D = $Title
@onready var timer: Timer = $Timer

var timer_ticktock: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	white_shot.visible = false
	title.play("default")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _unhandled_input(_Input) -> void:
	if Input.is_action_just_pressed("light_match"):
		white_shot.visible = true
		timer.start()
		timer_ticktock = true
		await timer.timeout
		get_tree().change_scene_to_file("res://scenes/levels/level/container.tscn")
		
