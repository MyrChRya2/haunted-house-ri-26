extends CharacterBody2D

const STEP_INTO_ROOM := 8.0  # 穿过缺口后再往里走几格
const DOOR_LAYER := 5  # 填门单独那一层的层号，不要和墙共用

@export var speed := 30.0
@export var current_floor := 1
@export var flee_seconds := 1.0
@export var stuck_seconds := 1.2
@export var ignores_locked_doors := false
@export var ignores_scepter := false
@export var uses_stairs := false

var room_id := ""
var _came_from := ""
var _path: Array[Vector2] = []
var _floor_delta := 0
var _skip_stairs := false
var _flee_left := 0.0
var _stuck_time := 0.0
var _last_dist := INF
var _player
var _loader

@onready var _hurt: Area2D = $HurtArea

func _ready() -> void:
	# 身体 mask：墙 + 门。穿门怪才去掉门这一层
	if ignores_locked_doors:
		set_collision_mask_value(DOOR_LAYER, false)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_loader = get_tree().get_first_node_in_group("floor_loader")
	_hurt.body_entered.connect(_on_hurt_body_entered)
	room_id = HouseData.room_at(global_position)
	_pick_exit()

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var same_floor: bool = current_floor == _player.current_floor
	visible = same_floor
	_hurt.set_deferred("monitoring", same_floor)

	if _flee_left > 0.0:
		_flee_left -= delta
		_move((global_position - _player.global_position).normalized(), delta, same_floor)
		_update_room()
		return

	var target: Vector2
	if same_floor and _can_scare() and room_id == HouseData.room_at(_player.global_position):
		target = _player.global_position
	else:
		if _path.is_empty():
			_pick_exit()
			if _path.is_empty():
				return
		target = _path[0]
		if global_position.distance_to(target) <= maxf(1.0, speed * delta):
			global_position = target
			_path.pop_front()
			_stuck_time = 0.0
			_last_dist = INF
			if _path.is_empty() and _floor_delta != 0:
				current_floor = clampi(current_floor + _floor_delta, 1, 4)
				_came_from = ""
				_skip_stairs = true
				_pick_exit()
			return
		var dist := global_position.distance_to(target)
		if dist < _last_dist - 0.1:
			_stuck_time = 0.0
		else:
			_stuck_time += delta
		_last_dist = dist
		if _stuck_time > stuck_seconds:
			_pick_exit()
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
	if r != "" and r != room_id:
		_came_from = room_id
		room_id = r
		_pick_exit()

func _pick_exit() -> void:
	_stuck_time = 0.0
	_last_dist = INF
	var options := []
	for e in HouseData.get_exits(room_id):
		if ignores_locked_doors or _loader.is_door_open(current_floor, e.door_position):
			options.append(e)
	var forward := options.filter(func(e): return e.to != _came_from)
	if not forward.is_empty():
		options = forward
	if uses_stairs and not _skip_stairs:
		options.append_array(HouseData.get_stairs(current_floor, room_id))
	_skip_stairs = false
	_path.clear()
	_floor_delta = 0
	if options.is_empty():
		return
	var pick: Dictionary = options.pick_random()
	if pick.has("floor_delta"):
		_path.append(pick.pos)
		_floor_delta = pick.floor_delta
	else:
		var door: Vector2 = pick.door_position
		var into: Vector2 = HouseData.ROOMS[pick.to].get_center() - door
		into = Vector2(signf(into.x), 0) if absf(into.x) > absf(into.y) else Vector2(0, signf(into.y))
		_path.append(door - into * STEP_INTO_ROOM)
		_path.append(door)
		_path.append(door + into * STEP_INTO_ROOM)

func _can_scare() -> bool:
	return ignores_scepter or _player.get_held() != HeldItemInventory.HeldItem.SCEPTER

func _on_hurt_body_entered(body: Node) -> void:
	if body != _player or current_floor != _player.current_floor or not _can_scare():
		return
	_player.take_damage()
	_flee_left = flee_seconds
