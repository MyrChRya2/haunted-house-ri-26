extends Area2D
#挂载到想要用的area节点上
#楼梯我已经修改完了功能一样不需要重复

#把想要去的场景拖到右边检查器的nextsences
#spawnid是下一个地图玩家出生的节点名，节点用mark2d
@export var next_scene: PackedScene
@export var spawn_id: String = ""

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if next_scene == null:
		push_warning("map_portal: 没指定 next_scene")
		return
	MapTravel.spawn_id = spawn_id
	MapTravel.save_from(body)
	get_tree().change_scene_to_packed(next_scene)
