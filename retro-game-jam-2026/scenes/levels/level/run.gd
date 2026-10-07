extends Node2D
#挂容器根节点，把场景实例进容器
@export var start_level: String = "Level1"
@export var start_spawn: String = ""
@export var travel_cooldown: float = 0.35

var _current: Node2D
var _cool: float = 0.0

func _ready() -> void:
	if get_node_or_null("Levels") == null:
		push_error("run.gd 只能挂在带 Levels 子节点的 Container 上，当前节点：%s" % get_path())
		return
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

func _levels() -> Node2D:
	return get_node_or_null("Levels") as Node2D

# Marker 若夹在普通 Node 下面，自带的 global_position 不会带上所在层在容器里的偏移
func _world_pos(node: Node2D) -> Vector2:
	var xform := Transform2D.IDENTITY
	var n: Node = node
	while n:
		if n is Node2D:
			xform = (n as Node2D).transform * xform
		n = n.get_parent()
	return xform.origin

func _travel(level_name: String, spawn_id: String, player: Node2D, is_boot: bool) -> void:
	var levels := _levels()
	if levels == null:
		push_warning("Run: 当前节点没有 Levels")
		return
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
			player.global_position = _world_pos(marker)
		else:
			push_warning("Run: 层 %s 没有 Marker2D「%s」" % [level_name, spawn_id])
	elif is_boot:
		pass

func get_current_level() -> Node2D:
	return _current

#从任意节点往上找到 Levels 下的那一层
func level_of(node: Node) -> Node2D:
	var levels := _levels()
	if levels == null:
		return _current
	var n := node
	while n:
		if n.get_parent() == levels:
			return n as Node2D
		n = n.get_parent()
	return _current

#怪换图：只挪这个节点，不动玩家、不走玩家冷却
func teleport_actor(actor: Node2D, level_name: String, spawn_id: String) -> void:
	var levels := _levels()
	if levels == null:
		push_warning("Run: 当前节点没有 Levels")
		return
	var target := levels.get_node_or_null(level_name) as Node2D
	if target == null:
		push_warning("Run: 找不到层 %s" % level_name)
		return
	if actor.get_parent() != target:
		actor.reparent(target)
	if spawn_id != "":
		var marker := target.find_child(spawn_id, true, false) as Marker2D
		if marker:
			actor.global_position = _world_pos(marker)
		else:
			push_warning("Run: 层 %s 没有 Marker2D「%s」" % [level_name, spawn_id])
