extends Area2D

@export var target_level: String = ""
@export var spawn_id: String = ""
#计数功能废弃，只做传送和装饰作用
enum Kind { UP, DOWN }
@export var kind: Kind = Kind.DOWN


func _ready() -> void:
	add_to_group("monster_exit")
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.has_method("try_use_stair"):
		return
	#下楼，计数器-1
	#body.try_use_stair(1 if kind == Kind.UP else -1)
	#传送用
	if target_level.is_empty():
		return
	var run := get_tree().get_first_node_in_group("run")
	if run and run.has_method("travel_to"):
		run.travel_to(target_level, spawn_id)
