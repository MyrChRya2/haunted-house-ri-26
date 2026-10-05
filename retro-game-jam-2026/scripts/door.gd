extends StaticBody2D


@onready var _collision: CollisionShape2D = $CollisionShape2D

@onready var _detect: Area2D = $Area2D

#门的状态
var is_open: bool = false


func _ready() -> void:
	_detect.monitoring = true
	_detect.body_entered.connect(_on_detect_body_entered)
	#回到本层保持开门
	if is_open:
		_collision.disabled = true
		
func _on_detect_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	try_unlock(body)

func try_unlock(player: Node) -> bool:
	if is_open:
		return true
	if player == null or not player.has_method("has_key"):
		return false
	if not player.has_key():
		print("locked_door: need key")
		return false
	_open()
	return true

func _open() -> void:
	is_open = true
	_collision.set_deferred("disabled", true)
	print("locked_door: opened")
