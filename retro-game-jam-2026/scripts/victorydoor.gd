extends StaticBody2D
#判定游戏胜利的门，基本抄门的代码
class_name victorydoor

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _detect: Area2D = $Area2D
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

#信号发给玩家冻结操作，发给label显示youwin
signal win

var is_win: bool = false

func _ready() -> void:
	_detect.monitoring = true
	_detect.body_entered.connect(_on_detect_body_entered)
	_sprite.animation_finished.connect(_on_anim_finished)
	if is_win:
		_collision.disabled = true
		_sprite.play(&"opened")
	else:
		_collision.disabled = false
		_sprite.play(&"closed")

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("win"):
		win.connect(player.win)
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_method("_freeze") and not win.is_connected(m._freeze):
			win.connect(m._freeze)

func _on_detect_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var hub := get_tree().get_first_node_in_group("hub")
	if hub != null and hub.has_method("youwin") and not win.is_connected(hub.youwin):
		win.connect(hub.youwin)
	try_win(body)

func try_win(player: Node) -> bool:
	if is_win:
		return true
	if player == null or not player.has_method("has_weng"):
		return false
	if not player.has_weng():
		return false
	is_win = true
	_collision.set_deferred("disabled", true)
	_sprite.play(&"openanima")
	win.emit()
	return true

func _on_anim_finished() -> void:
	if _sprite.animation == &"openanima":
		_sprite.play(&"opened")
