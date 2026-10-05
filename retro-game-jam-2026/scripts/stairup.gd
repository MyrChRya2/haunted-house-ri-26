extends Area2D



enum Kind { UP, DOWN }
@export var kind: Kind = Kind.UP

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
#防报错
	if not body.is_in_group("player"):
		return
	if not body.has_method("try_use_stair"):
		return
#上楼
	body.try_use_stair(1 if kind == Kind.UP else -1)
