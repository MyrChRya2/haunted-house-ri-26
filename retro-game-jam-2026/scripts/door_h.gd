extends StaticBody2D

var _collision: CollisionShape2D
var _sprite: AnimatedSprite2D
var _detect: Area2D
var is_open: bool = false

func _ready() -> void:
	_collision = _find_shape()
	_detect = _find_area()
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _detect:
		_detect.monitoring = true
		if not _detect.body_entered.is_connected(_on_detect_body_entered):
			_detect.body_entered.connect(_on_detect_body_entered)
	if _sprite and not _sprite.animation_finished.is_connected(_on_anim_finished):
		_sprite.animation_finished.connect(_on_anim_finished)
	if is_open:
		_set_blocked(false)
		_play([&"opend", &"opened"])
	else:
		_set_blocked(true)
		_play([&"close", &"closed"])

func _find_shape() -> CollisionShape2D:
	for name in ["Collision", "CollisionShape2D"]:
		var node := get_node_or_null(name)
		if node is CollisionShape2D:
			return node
	return null

func _find_area() -> Area2D:
	for name in ["UnlockArea", "Area2D"]:
		var node := get_node_or_null(name)
		if node is Area2D:
			return node
	return null

func _set_blocked(blocked: bool) -> void:
	if _collision:
		_collision.set_deferred("disabled", not blocked)

func _play(names: Array[StringName]) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	for n in names:
		if _sprite.sprite_frames.has_animation(n):
			_sprite.play(n)
			return

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
		return false
	_open()
	return true

func _open() -> void:
	is_open = true
	_set_blocked(false)
	_play([&"openanima"])

func _on_anim_finished() -> void:
	if _sprite and _sprite.animation == &"openanima":
		_play([&"opend", &"opened"])
