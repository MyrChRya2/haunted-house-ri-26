extends Sprite2D


@export var rotation_period: float = 3.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _physics_process(_delta: float) -> void:
	rotation += TAU / rotation_period * _delta
	pass
