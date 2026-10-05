extends CharacterBody2D

const DOOR_LAYER := 5
const JOIN_EPS := 1.5

@export var speed := 30.0
@export var current_floor := 1
@export var flee_seconds := 1.0
@export var stuck_seconds := 1.2
@export var ignores_locked_doors := false
@export var ignores_scepter := false
@export var uses_stairs := false

var room_id := ""
var _path: Array[Vector2] = []
var _prev_node := Vector2.INF
var _floor_delta := 0
var _skip_stairs := false
var _flee_left := 0.0
var _stuck_time := 0.0
var _last_dist := INF
var _was_chasing := false
var _player
var _loader

@onready var _hurt: Area2D = $HurtArea


func _ready() -> void:
	add_to_group("monsters")
	if ignores_locked_doors:
		set_collision_mask_value(DOOR_LAYER, false)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_loader = get_tree().get_first_node_in_group("floor_loader")
	_hurt.body_entered.connect(_on_hurt_body_entered)
	if _player:
		_player.hit_invincible_started.connect(_stop_chase)
		_player.scepter_invincible_started.connect(_stop_chase)
		_player.monsters_redeploy.connect(_redeploy)
	room_id = HouseData.room_at(global_position)
	_start_patrol()

var freeze : bool = false
#冻结行动用
func _freeze():
	freeze = true


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if freeze == true:
		return
	var same_floor: bool = current_floor == _player.current_floor
	visible = same_floor
	_hurt.set_deferred("monitoring", same_floor)

	if _flee_left > 0.0:
		_flee_left -= delta
		_move((global_position - _player.global_position).normalized(), delta, same_floor)
		_update_room()
		_was_chasing = true
		return

	var chasing := (
		same_floor
		and _can_chase()
		and room_id != ""
		and room_id == HouseData.room_at(_player.global_position)
	)
	if chasing:
		_was_chasing = true
		_path.clear()
		_move(global_position.direction_to(_player.global_position), delta, same_floor)
		_update_room()
		return

	if _was_chasing:
		_was_chasing = false
		_start_patrol()

	if _path.is_empty():
		_pick_next()
		if _path.is_empty():
			return

	var target: Vector2 = _path[0]
	if global_position.distance_to(target) <= maxf(JOIN_EPS, speed * delta):
		global_position = target
		_path.pop_front()
		_stuck_time = 0.0
		_last_dist = INF
		if _path.is_empty() and _floor_delta != 0:
			current_floor = clampi(current_floor + _floor_delta, 1, 4)
			_skip_stairs = true
			_prev_node = Vector2.INF
			_start_patrol()
		elif _path.is_empty():
			_pick_next()
		return

	var dist := global_position.distance_to(target)
	if dist < _last_dist - 0.1:
		_stuck_time = 0.0
	else:
		_stuck_time += delta
	_last_dist = dist
	if _stuck_time > stuck_seconds:
		_start_patrol()
		return

	_move(global_position.direction_to(target), delta, same_floor)
	_update_room()


func _move(dir: Vector2, delta: float, same_floor: bool) -> void:
	if same_floor:
		velocity = dir * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		global_position += dir * speed * delta


func _update_room() -> void:
	var r := HouseData.room_at(global_position)
	if r != "":
		room_id = r


func _stop_chase() -> void:
	_was_chasing = false
	_flee_left = 0.0
	_path.clear()
	_start_patrol()


func _redeploy() -> void:
	current_floor = randi_range(1, 4)
	global_position = HouseData.random_patrol_point()
	room_id = HouseData.room_at(global_position)
	_prev_node = Vector2.INF
	_flee_left = 0.0
	_was_chasing = false
	_floor_delta = 0
	_skip_stairs = false
	_path.clear()
	_start_patrol()


func _start_patrol() -> void:
	_stuck_time = 0.0
	_last_dist = INF
	_floor_delta = 0
	_path = _join_path(global_position)
	if _path.is_empty():
		_pick_next()


func _pick_next() -> void:
	_stuck_time = 0.0
	_last_dist = INF
	_floor_delta = 0
	if _loader == null:
		return

	var here := _nearest_node(global_position)
	if global_position.distance_to(here) > JOIN_EPS:
		_path = _join_path(global_position)
		return

	global_position = here
	var options: Array[Vector2] = []
	for n in _neighbors(here):
		if _edge_open(here, n):
			options.append(n)

	var forward: Array[Vector2] = []
	for n in options:
		if n != _prev_node:
			forward.append(n)
	if not forward.is_empty():
		options = forward

	if uses_stairs and not _skip_stairs:
		for s in HouseData.get_stairs(current_floor, HouseData.room_at(here)):
			options.append(s.pos)
	_skip_stairs = false

	if options.is_empty():
		if _prev_node != Vector2.INF and _edge_open(here, _prev_node):
			options.append(_prev_node)
		else:
			return

	var pick: Vector2 = options.pick_random()
	_prev_node = here
	_path.clear()

	var stair_delta := 0
	for s in HouseData.get_stairs(current_floor, HouseData.room_at(here)):
		if s.pos == pick:
			stair_delta = s.floor_delta
			break
	if stair_delta != 0:
		_path.append(pick)
		_floor_delta = stair_delta
	else:
		_path.append(pick)


func _join_path(from: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	var proj := _project_to_rail(from)
	if from.distance_to(proj) > JOIN_EPS:
		path.append(proj)
	var node := _nearest_node(proj)
	if proj.distance_to(node) > JOIN_EPS:
		path.append(node)
	_prev_node = Vector2.INF
	return path


func _project_to_rail(p: Vector2) -> Vector2:
	var xs: Array = HouseData.PATROL_XS
	var ys: Array = HouseData.PATROL_YS
	var best := p
	var best_d := INF
	var y0: float = ys[0]
	var y1: float = ys[ys.size() - 1]
	var x0: float = xs[0]
	var x1: float = xs[xs.size() - 1]
	for x in xs:
		var q := Vector2(x, clampf(p.y, y0, y1))
		var d := p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
	for y in ys:
		var q2 := Vector2(clampf(p.x, x0, x1), y)
		var d2 := p.distance_squared_to(q2)
		if d2 < best_d:
			best_d = d2
			best = q2
	return best


func _nearest_node(p: Vector2) -> Vector2:
	var xs: Array = HouseData.PATROL_XS
	var ys: Array = HouseData.PATROL_YS
	var best := Vector2(xs[0], ys[0])
	var best_d := INF
	for x in xs:
		for y in ys:
			var n := Vector2(x, y)
			var d := p.distance_squared_to(n)
			if d < best_d:
				best_d = d
				best = n
	return best


func _neighbors(node: Vector2) -> Array[Vector2]:
	var xs: Array = HouseData.PATROL_XS
	var ys: Array = HouseData.PATROL_YS
	var out: Array[Vector2] = []
	var xi := xs.find(node.x)
	var yi := ys.find(node.y)
	if xi < 0 or yi < 0:
		return out
	if xi > 0:
		out.append(Vector2(xs[xi - 1], node.y))
	if xi < xs.size() - 1:
		out.append(Vector2(xs[xi + 1], node.y))
	if yi > 0:
		out.append(Vector2(node.x, ys[yi - 1]))
	if yi < ys.size() - 1:
		out.append(Vector2(node.x, ys[yi + 1]))
	return out


func _edge_open(a: Vector2, b: Vector2) -> bool:
	if ignores_locked_doors or _loader == null:
		return true
	var door := _door_on_edge(a, b)
	if door == Vector2.INF:
		return true
	return _loader.is_door_open(current_floor, door)


func _door_on_edge(a: Vector2, b: Vector2) -> Vector2:
	for link in HouseData.LINKS:
		var d: Vector2 = link.door_position
		if _on_segment(d, a, b):
			return d
	return Vector2.INF


func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var ap := p - a
	if absf(ab.x) > absf(ab.y):
		if not is_equal_approx(p.y, a.y):
			return false
		var t := ap.x / ab.x
		return t > 0.05 and t < 0.95
	if not is_equal_approx(p.x, a.x):
		return false
	var t2 := ap.y / ab.y
	return t2 > 0.05 and t2 < 0.95



func _can_chase() -> bool:
	if _player.is_invincible:
		return false
	if not ignores_scepter and _player.scepter_invincible:
		return false
	return true


func _can_scare() -> bool:
	return _can_chase()


func _on_hurt_body_entered(body: Node) -> void:
	if body != _player or current_floor != _player.current_floor or not _can_scare():
		return
	_player.take_damage()
	_flee_left = 0.0
