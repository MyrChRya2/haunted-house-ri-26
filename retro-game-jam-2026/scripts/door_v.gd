extends StaticBody2D

@onready var _collision: CollisionShape2D = $Collision
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _detect: Area2D = $UnlockArea
@onready var navigation_obstacle_2d: NavigationObstacle2D = $NavigationObstacle2D

#门的状态
var is_open: bool = false

func _ready() -> void:
	_detect.monitoring = true
	_detect.body_entered.connect(_on_detect_body_entered)
	_sprite.animation_finished.connect(_on_anim_finished)
	if is_open:
		_collision.disabled = true
		_sprite.play(&"opend")
	else:
		_collision.disabled = false
		_sprite.play(&"close")
	_sync_nav_obstacle()

func _on_detect_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	try_unlock(body)

#开门
func try_unlock(player: Node) -> bool:
	if is_open:
		return true
	if player == null or not player.has_method("has_key"):
		return false
	if not player.has_key():
		return false
	_open()
	return true

func _open() -> void:
	is_open = true
	_collision.set_deferred("disabled", true)
	_sprite.play(&"openanima")
	_sync_nav_obstacle()

#播放动画
func _on_anim_finished() -> void:
	if _sprite.animation == &"openanima":
		_sprite.play(&"opend")

#关门挡路，开了就从寻路里拿掉
func _sync_nav_obstacle() -> void:
	navigation_obstacle_2d.avoidance_enabled = not is_open
	navigation_obstacle_2d.affect_navigation_mesh = not is_open
