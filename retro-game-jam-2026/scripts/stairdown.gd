extends Area2D

@export var next_scene: PackedScene
@export var spawn_id: String = ""


enum Kind { UP, DOWN }
@export var kind: Kind = Kind.DOWN


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("try_use_stair"):
		return
#下楼，计数器-1
	body.try_use_stair(1 if kind == Kind.UP else -1)
#传送用
	if next_scene == null:
		push_warning("map_portal: 没指定 next_scene")
		return
	MapTravel.spawn_id = spawn_id
	get_tree().change_scene_to_packed(next_scene)
