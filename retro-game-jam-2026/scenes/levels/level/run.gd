extends Node2D
#挂容器根节点，把场景实例进容器
@export var start_level: String = "Level1"
@export var start_spawn: String = ""
@export var travel_cooldown: float = 0.35

var _current: Node2D
var _cool: float = 0.0

func _ready() -> void:
	add_to_group("run")
	var player := get_tree().get_first_node_in_group("player")
	_travel(start_level, start_spawn, player, true)

func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta

func travel_to(level_name: String, spawn_id: String) -> void:
	if _cool > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_travel(level_name, spawn_id, player, false)
	_cool = travel_cooldown

func _travel(level_name: String, spawn_id: String, player: Node2D, is_boot: bool) -> void:
	var levels := $Levels
	var target := levels.get_node_or_null(level_name) as Node2D
	if target == null:
		push_warning("Run: 找不到层 %s" % level_name)
		return
	# 方案 A：层已错开摆放，全部保持可见，走过去就能进邻图。
	for child in levels.get_children():
		child.visible = true
	_current = target
	if spawn_id != "":
		var marker := target.find_child(spawn_id, true, false) as Marker2D
		if marker:
			player.global_position = marker.global_position
		else:
			push_warning("Run: 层 %s 没有 Marker2D「%s」" % [level_name, spawn_id])
	elif is_boot:
		pass
