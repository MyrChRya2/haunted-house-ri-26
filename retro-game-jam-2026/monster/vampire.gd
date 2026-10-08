extends CharacterBody2D
#吸血鬼

enum State { WANDER, GO_EXIT, CHASE, FLEE, VANISH }

@onready var hurt_area: Area2D = $HurtArea
@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var _sfx_wind: AudioStreamPlayer = $wind

@export var speed: float = 30.0
#追击时速度
@export var chase_speed: float = 46.0
#游荡时去找门口/楼梯的概率
@export var exit_chance: float = 0.45
#每隔几秒抽一次出门
@export var room_dwell: float = 3.0
@export var flee_seconds: float = 1.5
@export var arrive_distance: float = 16.0

const WAYPOINT := 5.0
const RESET_ANIM := &"reset"

var freeze: bool = false
var _player: Node = null
var _match: Node = null
var _run: Node = null
var _state: State = State.WANDER
var _was_hitter: bool = false
#重新投放动画正在播（播完才允许改朝向动画）
var _resetting: bool = false
#最近一次朝向动画，reset 播完回到它
var _facing_anim: StringName = &"normal_right"
var _flee_left: float = 0.0
var _exit: Area2D = null
var _exit_cool: float = 0.0
var _room_t: float = 0.0
var _goal: Vector2 = Vector2.ZERO
var _prev_goal: Vector2 = Vector2.ZERO
var _path: Array[Vector2] = []
var _stuck_pos: Vector2 = Vector2.ZERO
var _stuck_t: float = 0.0
var _chase_pos: Vector2 = Vector2(-9999, -9999)
var _nav_level: Node = null
var _r: float = 4.0
var _probe := CircleShape2D.new()

func _ready() -> void:
	add_to_group("monsters")
	add_to_group("monster")
	hurt_area.body_entered.connect(_on_hurt_body_entered)
	#reset 播完接回朝向动画；Ray 还没画帧时它是零帧动画，播不了
	if body_sprite and not body_sprite.animation_finished.is_connected(_on_body_anim_finished):
		body_sprite.animation_finished.connect(_on_body_anim_finished)
	_remember_facing()
	agent.avoidance_enabled = false
	agent.path_desired_distance = 6.0
	agent.target_desired_distance = 10.0
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		_r = (cs.shape as CircleShape2D).radius
	set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = get_tree().get_first_node_in_group("player")
	_run = get_tree().get_first_node_in_group("run")
	if _player:
		if _player.has_node("MatchLight"):
			_match = _player.get_node("MatchLight")
		_player.hit_invincible_started.connect(_on_hit_invincible_started)
		_player.scepter_invincible_started.connect(_on_scepter_invincible_started)
		_player.monsters_redeploy.connect(_on_monsters_redeploy)
		_player.player_dead.connect(_freeze)
	_bind_nav()
	_start_wander()
	set_physics_process(true)

func _freeze() -> void:
	freeze = true
	velocity = Vector2.ZERO
	_stop_sfx(_sfx_wind)

func _physics_process(delta: float) -> void:
	if freeze or _player == null:
		velocity = Vector2.ZERO
		return
	if _player.is_dead:
		_freeze()
		return
	_exit_cool = maxf(_exit_cool - delta, 0.0)
	_bind_nav()
	if _can_chase():
		if _state != State.CHASE:
			_play_sfx(_sfx_wind, true)
		_state = State.CHASE
	elif _state == State.CHASE:
		_start_wander()
	match _state:
		State.CHASE:
			var p := (_player as Node2D).global_position
			if p.distance_to(_chase_pos) > 8.0 or _path.is_empty():
				_chase_pos = p
				_set_goal(p)
		State.FLEE:
			_flee_left -= delta
			if _flee_left <= 0.0:
				_start_wander()
			else:
				_set_goal(_flee_point())
		State.GO_EXIT:
			if _exit == null or not is_instance_valid(_exit):
				_start_wander()
			elif _reached_exit(_exit):
				_use_exit(_exit)
				return
			elif _path.is_empty() or _goal.distance_to(_exit_point(_exit)) > 8.0:
				_set_goal(_exit_point(_exit))
		State.WANDER:
			_room_t += delta
			if _exit_cool <= 0.0 and _room_t >= room_dwell:
				_room_t = 0.0
				if randf() < exit_chance:
					_try_go_exit()
			if _state == State.WANDER and _path.is_empty() and global_position.distance_to(_goal) <= arrive_distance:
				_pick_wander()
		State.VANISH:
			velocity = Vector2.ZERO
			return
	_follow(delta)
	_update_facing()

#同房、火把亮、玩家没无敌才追
func _can_chase() -> bool:
	if _state == State.FLEE or _state == State.VANISH:
		return false
	var mine := _my_level()
	var cur: Node = _run.get_current_level() if _run else null
	if mine != null and cur != null and mine != cur:
		return false
	if _player.is_invincible:
		return false
	if _player.scepter_invincible:
		return false
	return _match != null and _match.has_method("is_burning") and _match.is_burning()

func _my_level() -> Node2D:
	return _run.level_of(self) if _run else get_parent() as Node2D

func _on_hit_invincible_started() -> void:
	if _state == State.VANISH:
		return
	if _was_hitter:
		_state = State.FLEE
		_flee_left = flee_seconds
		_set_goal(_flee_point())
	else:
		_start_wander()

func _on_scepter_invincible_started() -> void:
	if _state == State.CHASE:
		_start_wander()

func _on_monsters_redeploy() -> void:
	if freeze or _player == null or _player.is_dead or not _was_hitter:
		return
	_was_hitter = false
	_redeploy()

func _on_hurt_body_entered(body: Node) -> void:
	if body != _player:
		return
	var mine := _my_level()
	var cur: Node = _run.get_current_level() if _run else null
	if mine != null and cur != null and mine != cur:
		return
	if _player.is_invincible:
		return
	if _player.scepter_invincible:
		return
	_was_hitter = true
	_player.take_damage()

func _start_wander() -> void:
	_stop_sfx(_sfx_wind)
	_state = State.WANDER
	_exit = null
	_room_t = 0.0
	_chase_pos = Vector2(-9999, -9999)
	_stuck_t = 0.0
	_pick_wander()

func _try_go_exit() -> void:
	var ex := _random_exit()
	if ex == null:
		return
	_exit = ex
	_state = State.GO_EXIT
	_set_goal(_exit_point(ex))

func _pick_wander() -> void:
	_prev_goal = _goal
	_set_goal(_random_nav_point())

#换房后绑到那一层自己的导航图，不然会寻到隔壁房间
func _bind_nav() -> void:
	var level := _my_level()
	if level == _nav_level:
		return
	_nav_level = level
	var map := _nav_map()
	if map.is_valid() and agent:
		agent.set_navigation_map(map)

func _nav_map() -> RID:
	if _run:
		var map: RID = _run.nav_map_of(_my_level()) as RID
		if map.is_valid():
			return map
	return agent.get_navigation_map() if agent else RID()

func _closest_nav(p: Vector2) -> Vector2:
	var map := _nav_map()
	if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
		return Vector2.INF
	var c := NavigationServer2D.map_get_closest_point(map, p)
	#离网格太远说明点不在这张图上
	return Vector2.INF if c.distance_to(p) > 48.0 else c

func _set_goal(world: Vector2) -> void:
	_goal = world
	_path.clear()
	var map := _nav_map()
	var from := _closest_nav(global_position)
	var to := _closest_nav(world)
	if not map.is_valid() or from == Vector2.INF or to == Vector2.INF:
		return
	for raw in NavigationServer2D.map_get_path(map, from, to, true):
		var inset := _nudge_off_walls(raw as Vector2)
		if _path.is_empty() or _path[_path.size() - 1].distance_to(inset) > 2.0:
			_path.append(inset)

func _has_nav_path(to: Vector2) -> bool:
	var map := _nav_map()
	var from := _closest_nav(global_position)
	var dest := _closest_nav(to)
	if not map.is_valid() or from == Vector2.INF or dest == Vector2.INF:
		return false
	var pts := NavigationServer2D.map_get_path(map, from, dest, true)
	return not pts.is_empty() and pts[pts.size() - 1].distance_to(dest) <= 24.0

#网格上随机一个能走到、没被墙围死的点
func _random_nav_point() -> Vector2:
	var here := global_position
	var options: Array[Vector2] = []
	var map := _nav_map()
	if map.is_valid() and NavigationServer2D.map_get_iteration_id(map) != 0:
		for i in 16:
			var p := NavigationServer2D.map_get_random_point(map, 1, true)
			if (p != Vector2.ZERO or i > 0) and _ok_wander(p, here):
				options.append(p)
	if options.is_empty():
		for p in _nav_tiles():
			if _ok_wander(p, here):
				options.append(p)
	if options.is_empty():
		var c := _closest_nav(here)
		return here if c == Vector2.INF else c
	return options.pick_random()

func _ok_wander(p: Vector2, here: Vector2) -> bool:
	return p.distance_to(here) >= 24.0 and p.distance_to(_prev_goal) >= 24.0 and not _point_is_fenced(p) and _has_nav_path(p)

func _nav_tiles() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var level := _my_level()
	if level == null:
		return out
	var layer := level.find_child("Navigation", true, false)
	if not (layer is TileMapLayer):
		return out
	var tm := layer as TileMapLayer
	for cell in tm.get_used_cells():
		out.append(tm.to_global(tm.map_to_local(cell as Vector2i)))
	return out

func _flee_point() -> Vector2:
	if _player == null:
		return global_position
	var danger := (_player as Node2D).global_position
	var best := global_position
	var best_d := -1.0
	for p in _nav_tiles():
		var d := p.distance_squared_to(danger)
		if d > best_d and _has_nav_path(p):
			best_d = d
			best = p
	return best

func _fits(p: Vector2, r: float) -> bool:
	_probe.radius = r
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = _probe
	params.transform = Transform2D.IDENTITY.translated(p)
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_shape(params, 1).is_empty()

func _hit(from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = collision_mask
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(q)

#导航点贴多边形外沿，往开阔处挪一点
func _nudge_off_walls(base: Vector2) -> Vector2:
	var r := _r + 2.0
	var p := base
	for i in 6:
		if _fits(p, r):
			return p
		var acc := Vector2.ZERO
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var h := _hit(p, p + d.normalized() * (r + 4.0))
			var c := r + 4.0 if h.is_empty() else p.distance_to(h.position)
			if c < r:
				acc -= d.normalized() * (r - c)
		if acc == Vector2.ZERO:
			break
		p += acc
		if p.distance_to(base) > 8.0:
			p = base + (p - base).limit_length(8.0)
	return p if _fits(p, r) else base

func _follow(delta: float) -> void:
	#近了且中间没墙才直线贴，隔墙继续走路点
	if _state == State.CHASE and _player is Node2D:
		var p := (_player as Node2D).global_position
		if global_position.distance_to(p) <= 18.0:
			var h := _hit(global_position, p)
			if h.is_empty() or h.get("collider") == _player:
				_move(global_position.direction_to(p))
				_stuck_pos = global_position
				_stuck_t = 0.0
				_try_hit_player()
				return
	if not _path.is_empty():
		if global_position.distance_to(_path[0]) <= WAYPOINT:
			_path.pop_front()
			if _path.is_empty():
				if _state == State.CHASE and _player is Node2D:
					_move(global_position.direction_to((_player as Node2D).global_position))
					_try_hit_player()
					return
				_move(Vector2.ZERO)
				_check_stuck(delta)
				return
		_move(global_position.direction_to(_path[0]))
		if get_slide_collision_count() > 0 and velocity.length() < _move_speed() * 0.12 and not _path.is_empty():
			_path.pop_front()
		_try_hit_player()
		_check_stuck(delta)
		return
	if _state == State.GO_EXIT and _exit != null:
		_move(global_position.direction_to(_exit_point(_exit)))
	elif _state == State.WANDER:
		_pick_wander()
		_move(Vector2.ZERO)
	elif _state == State.CHASE and _player is Node2D:
		_move(global_position.direction_to((_player as Node2D).global_position))
		_try_hit_player()
		return
	else:
		_move(Vector2.ZERO)
	_check_stuck(delta)

#贴身时每帧查重叠，避免 area 进了却没进信号
func _try_hit_player() -> void:
	if _state != State.CHASE or _player == null or hurt_area == null:
		return
	if hurt_area.overlaps_body(_player):
		_on_hurt_body_entered(_player)

func _move_speed() -> float:
	return chase_speed if _state == State.CHASE else speed

func _move(dir: Vector2) -> void:
	velocity = dir * _move_speed() if dir != Vector2.ZERO else Vector2.ZERO
	move_and_slide()

func _check_stuck(delta: float) -> void:
	if _state == State.VANISH:
		return
	if _state == State.CHASE and _player is Node2D and global_position.distance_to((_player as Node2D).global_position) <= 22.0:
		_stuck_pos = global_position
		_stuck_t = 0.0
		return
	if global_position.distance_to(_stuck_pos) > 4.0:
		_stuck_pos = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < 0.55:
		return
	_stuck_t = 0.0
	_nav_level = null
	_bind_nav()
	if _state == State.CHASE:
		_chase_pos = Vector2(-9999, -9999)
		_set_goal((_player as Node2D).global_position)
	elif _state == State.GO_EXIT and _exit != null and is_instance_valid(_exit):
		#顶在外墙门口也算出门
		if _reached_exit(_exit) or global_position.distance_to(_exit_point(_exit)) <= 20.0:
			_use_exit(_exit)
		else:
			_set_goal(_exit_point(_exit))
	else:
		_pick_wander()

func _update_facing() -> void:
	if body_sprite == null:
		return
	if _resetting:
		return
	if absf(velocity.x) < absf(velocity.y) or absf(velocity.x) < 0.01:
		return
	var anim := &"normal_right" if velocity.x > 0.0 else &"normal_left"
	if _anim_has_frames(anim) and body_sprite.animation != anim:
		body_sprite.play(anim)
		_facing_anim = anim

func _random_exit() -> Area2D:
	var level := _my_level()
	var options: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("monster_exit"):
		if not (n is Area2D):
			continue
		var area := n as Area2D
		if str(area.get("target_level")) == "" or (level and not level.is_ancestor_of(area)):
			continue
		var p := _exit_point(area)
		var border := _is_border_point(p)
		#外墙门口不算围死；里面被墙围住或走不到的楼梯丢掉重抽
		if not border and (_point_is_fenced(p) or not _has_nav_path(p)):
			continue
		options.append(area)
	return options.pick_random() if not options.is_empty() else null

func _is_border_point(p: Vector2) -> bool:
	var level := _my_level()
	var local := p - (level.global_position if level else global_position)
	return local.x <= 16.0 or local.x >= 176.0 or local.y <= 16.0 or local.y >= 144.0

#三面有碰撞算围死；旁边门开了、碰撞关了算出路
func _point_is_fenced(p: Vector2) -> bool:
	var blocked := 0
	var open_door := false
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var h := _hit(p, p + d * 12.0)
		if not h.is_empty() and p.distance_to(h.position) <= 10.0:
			blocked += 1
		elif _open_door_on_side(p, d):
			open_door = true
	return not open_door and blocked >= 3

func _open_door_on_side(from: Vector2, dir: Vector2) -> bool:
	var level := _my_level()
	if level == null:
		return false
	for n in level.find_children("*", "StaticBody2D", true, false):
		if not (n.has_method("try_unlock") or n.has_method("try_win")):
			continue
		var opened = n.get("is_open") or n.get("is_win")
		if not opened:
			var col := n.get_node_or_null("Collision") as CollisionShape2D
			if col == null:
				col = n.get_node_or_null("CollisionShape2D") as CollisionShape2D
			opened = col != null and col.disabled
		if not opened:
			continue
		var to_door: Vector2 = (n as Node2D).global_position - from
		if to_door.length() <= 24.0 and to_door.normalized().dot(dir) > 0.35:
			return true
	return false

func _exit_point(area: Area2D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return (child as Node2D).global_position
	return area.global_position

#碰到门的碰撞盒才传，顶在墙边留一点余量
func _reached_exit(area: Area2D) -> bool:
	var slack := _r + 8.0
	for child in area.get_children():
		if not (child is CollisionShape2D):
			continue
		var cs := child as CollisionShape2D
		if cs.disabled or cs.shape == null:
			continue
		var xf := cs.global_transform
		if cs.shape is RectangleShape2D:
			var half: Vector2 = (cs.shape as RectangleShape2D).size * 0.5
			var local: Vector2 = xf.affine_inverse() * global_position
			var closest := Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y))
			if local.distance_to(closest) <= slack:
				return true
		elif cs.shape is CircleShape2D:
			if global_position.distance_to(xf.origin) <= slack + (cs.shape as CircleShape2D).radius:
				return true
	return false

func _after_warp() -> void:
	_nav_level = null
	_bind_nav()
	var c := _closest_nav(global_position)
	if c != Vector2.INF:
		global_position = c

func _use_exit(area: Area2D) -> void:
	var dest := str(area.get("target_level"))
	var spawn := str(area.get("spawn_id"))
	if dest == "" or _run == null:
		_start_wander()
		return
	_run.teleport_actor(self, dest, spawn)
	if spawn == "":
		var room := _my_level()
		if room:
			global_position = room.global_position + Vector2(96, 80)
	_after_warp()
	_exit = null
	_exit_cool = 0.45
	_room_t = 0.0
	_start_wander()

func _play_sfx(sfx: AudioStreamPlayer, restart: bool) -> void:
	if sfx == null or sfx.stream == null:
		return
	if restart or not sfx.playing:
		sfx.play()

func _stop_sfx(sfx: AudioStreamPlayer) -> void:
	if sfx and sfx.playing:
		sfx.stop()

func _play_reset() -> void:
	#零帧动画 play() 是空操作，这里直接跳过，免得留下"正在重置"的假状态
	if not _anim_has_frames(RESET_ANIM):
		_resetting = false
		return
	#编辑器里 reset 是循环的：不关掉会永远停在 reset 上，朝向动画再也回不来
	if body_sprite.sprite_frames.get_animation_loop(RESET_ANIM):
		body_sprite.sprite_frames.set_animation_loop(RESET_ANIM, false)
	_resetting = true
	body_sprite.play(RESET_ANIM)

#reset 播完了：放回朝向动画，继续巡楼/追击
func _on_body_anim_finished() -> void:
	if body_sprite.animation != RESET_ANIM:
		return
	_resetting = false
	if _anim_has_frames(_facing_anim):
		body_sprite.play(_facing_anim)

#这套 SpriteFrames 里这个动画有没有真帧（有动画名但零帧＝播不了）
func _anim_has_frames(anim: StringName) -> bool:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return false
	return body_sprite.sprite_frames.has_animation(anim) and body_sprite.sprite_frames.get_frame_count(anim) > 0

#记住当前朝向动画，reset 播完要回到它
func _remember_facing() -> void:
	if body_sprite == null:
		return
	if body_sprite.animation != RESET_ANIM and _anim_has_frames(body_sprite.animation):
		_facing_anim = body_sprite.animation
	elif not _anim_has_frames(_facing_anim):
		_facing_anim = &"normal_right"

func _redeploy() -> void:
	_state = State.VANISH
	velocity = Vector2.ZERO
	_stop_sfx(_sfx_wind)
	_play_reset()
	var zones: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("spawn_zone"):
		if n is Area2D:
			zones.append(n)
	if zones.is_empty():
		_start_wander()
		return
	var zone: Area2D = zones.pick_random()
	if _run:
		_run.teleport_actor(self, _run.level_of(zone).name, "")
	global_position = _point_in_zone(zone)
	_after_warp()
	_start_wander()

func _point_in_zone(area: Area2D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var r: Vector2 = (child.shape as RectangleShape2D).size * 0.5
			return child.global_transform * Vector2(randf_range(-r.x, r.x), randf_range(-r.y, r.y))
	return area.global_position
