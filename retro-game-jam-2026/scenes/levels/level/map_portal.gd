extends Area2D
#挂载到想要用的area节点上
#楼梯我已经修改完了功能一样不需要重复

#把想要去的场景拖到右边检查器的target_level
#spawnid是下一个地图玩家出生的节点名，节点用mark2d
@export var target_level: String = ""
@export var spawn_id: String = ""

func _ready() -> void:
	add_to_group("monster_exit")
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if target_level.is_empty():
		push_warning("portal: 没填 target_level")
		return
	var run := get_tree().get_first_node_in_group("run")
	if run == null or not run.has_method("travel_to"):
		push_warning("portal: 场景里没有 Run")
		return
	run.travel_to(target_level, spawn_id)
