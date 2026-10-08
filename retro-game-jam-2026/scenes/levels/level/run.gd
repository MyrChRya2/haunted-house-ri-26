extends Node2D
#挂容器根节点，把场景实例进容器
@export var start_level: String = "Level1"
@export var start_spawn: String = ""
@export var travel_cooldown: float = 0.35

var _current: Node2D
var _cool: float = 0.0
var _wiping: bool = false

func _ready() -> void:
	if get_node_or_null("Levels") == null:
		push_error("run.gd 只能挂在带 Levels 子节点的 Container 上，当前节点：%s" % get_path())
		return
	add_to_group("run")
	_bind_level_nav_maps()
	var player := get_tree().get_first_node_in_group("player")
	_travel(start_level, start_spawn, player, true)

#每层一张导航图，避免怪寻路到隔壁房间后在隔墙上蹭
func _bind_level_nav_maps() -> void:
	var levels := _levels()
	if levels == null:
		return
	var cell := 1.0
	var world := get_world_2d()
	if world:
		var default_map: RID = world.get_navigation_map()
		if default_map.is_valid():
			cell = NavigationServer2D.map_get_cell_size(default_map)
	for child in levels.get_children():
		if not (child is Node2D):
			continue
		var level := child as Node2D
		if level.has_meta("nav_map"):
			continue
		var map := NavigationServer2D.map_create()
		NavigationServer2D.map_set_active(map, true)
		NavigationServer2D.map_set_cell_size(map, cell)
		level.set_meta("nav_map", map)
		_assign_nav_map(level, map)

func _assign_nav_map(node: Node, map: RID) -> void:
	if node is TileMapLayer:
		(node as TileMapLayer).set_navigation_map(map)
	elif node is NavigationObstacle2D:
		(node as NavigationObstacle2D).set_navigation_map(map)
	elif node is NavigationAgent2D:
		(node as NavigationAgent2D).set_navigation_map(map)
	for c in node.get_children():
		_assign_nav_map(c, map)

func nav_map_of(level: Node) -> RID:
	if level and level.has_meta("nav_map"):
		return level.get_meta("nav_map") as RID
	return RID()

func _process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta

func travel_to(level_name: String, spawn_id: String) -> void:
	if _wiping or _cool > 0.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	#进门那一帧的移动方向，用来转蒙版
	var move: Vector2 = player.velocity
	_wiping = true
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var wipe := get_node_or_null("SceneWipe")
	if wipe and wipe.has_method("play_cover"):
		await wipe.play_cover(move)
	_travel(level_name, spawn_id, player, false)
	if wipe and wipe.has_method("play_reveal"):
		await wipe.play_reveal(move)
	player.set_physics_process(true)
	_cool = travel_cooldown
	_wiping = false

func _levels() -> Node2D:
	return get_node_or_null("Levels") as Node2D

#Marker若夹在普通Node下面，自带的global_position不会带上所在层在容器里的偏移
#必须使用node2d
func _world_pos(node: Node2D) -> Vector2:
	var xform := Transform2D.IDENTITY
	var n: Node = node
	while n:
		if n is Node2D:
			xform = (n as Node2D).transform * xform
		n = n.get_parent()
	return xform.origin

func _find_level(level_name: String) -> Node2D:
	var levels := _levels()
	if levels == null:
		return null
	var target := levels.get_node_or_null(level_name) as Node2D
	if target:
		return target
	var want := level_name.to_lower()
	for child in levels.get_children():
		if child is Node2D and child.name.to_lower() == want:
			return child as Node2D
	return null

func _find_marker(level: Node2D, spawn_id: String) -> Marker2D:
	if spawn_id == "":
		return null
	var exact := level.find_child(spawn_id, true, false)
	if exact is Marker2D:
		return exact as Marker2D
	var want := spawn_id.to_lower()
	for n in level.find_children("*", "Marker2D", true, false):
		if str(n.name).to_lower() == want:
			return n as Marker2D
	return null

func _spawn_world_pos(level: Node2D, spawn_id: String) -> Vector2:
	var marker := _find_marker(level, spawn_id)
	if marker:
		return _world_pos(marker)
	if spawn_id != "":
		push_warning("Run: 层 %s 没有 Marker2D「%s」" % [level.name, spawn_id])
	return level.global_position + Vector2(96, 80)

func _travel(level_name: String, spawn_id: String, player: Node2D, is_boot: bool) -> void:
	var levels := _levels()
	if levels == null:
		push_warning("Run: 当前节点没有 Levels")
		return
	var target := _find_level(level_name)
	if target == null:
		push_warning("Run: 找不到层 %s" % level_name)
		return
	#打开其他地图的可视
	for child in levels.get_children():
		child.visible = true
	_current = target
	if spawn_id != "":
		player.global_position = _spawn_world_pos(target, spawn_id)
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
	var target := _find_level(level_name)
	if target == null:
		push_warning("Run: 找不到层 %s" % level_name)
		return
	if actor.get_parent() != target:
		actor.reparent(target)
	var map := nav_map_of(target)
	if map.is_valid():
		var agent := actor.get_node_or_null("NavigationAgent2D") as NavigationAgent2D
		if agent:
			agent.set_navigation_map(map)
	if spawn_id != "":
		actor.global_position = _spawn_world_pos(target, spawn_id)
