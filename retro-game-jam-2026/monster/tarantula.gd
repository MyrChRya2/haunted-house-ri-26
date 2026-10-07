extends CharacterBody2D
#蜘蛛自己的 AI：走导航绕墙，速度较慢

enum State { WANDER, GO_EXIT, CHASE, FLEE, VANISH }

@onready var hurt_area: Area2D = $HurtArea
@onready var body_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

@export var speed: float = 24.0
#不怕权杖则拿 shild 时仍可追、可打（默认怕）
@export var ignores_scepter: bool = false
#穿墙：不走网格、直线飞
@export var phase_through_walls: bool = false
#游荡结束时改去出口的概率
@export var exit_chance: float = 0.35
@export var flee_seconds: float = 1.5
@export var arrive_distance: float = 10.0

var freeze: bool = false
var _player: Node = null
var _match: Node = null
var _run: Node = null
var _state: State = State.WANDER
var _was_hitter: bool = false
var _flee_left: float = 0.0
var _exit: Area2D = null
var _move_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("monsters")
	add_to_group("monster")
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = arrive_distance
	navigation_agent.avoidance_enabled = false
	hurt_area.body_entered.connect(_on_hurt_body_entered)
	#等一帧，导航图和玩家都进树
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
	_start_wander()

#胜利门 / 玩家死亡冻结
func _freeze() -> void:
	freeze = true
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if freeze or _player == null:
		velocity = Vector2.ZERO
		return
	if _player.is_dead:
		_freeze()
		return
	if _can_chase():
		_state = State.CHASE
	elif _state == State.CHASE:
		_start_wander()
	match _state:
		State.CHASE:
			_set_nav_target(_player.global_position)
		State.FLEE:
			_flee_left -= delta
			if _flee_left <= 0.0:
				_start_wander()
			else:
				_set_nav_target(_flee_point())
		State.GO_EXIT:
			if _exit == null or not is_instance_valid(_exit):
				_start_wander()
			elif global_position.distance_to(_exit.global_position) <= arrive_distance:
				_use_exit(_exit)
				return
			else:
				_set_nav_target(_exit.global_position)
		State.WANDER:
			if navigation_agent.is_navigation_finished() or global_position.distance_to(_move_target) <= arrive_distance:
				_pick_next_idle()
		State.VANISH:
			velocity = Vector2.ZERO
			return
	_move_along_path()
	_update_facing()

#追击：同图 + 火把燃烧 + 两种无敌都没有
func _can_chase() -> bool:
	if _state == State.FLEE or _state == State.VANISH:
		return false
	if not _same_level_as_player():
		return false
	if _player.is_invincible:
		return false
	if not ignores_scepter and _player.scepter_invincible:
		return false
	return _torch_burning()

func _torch_burning() -> bool:
	if _match == null:
		return false
	if _match.has_method("is_burning"):
		return _match.is_burning()
	return false

func _same_level_as_player() -> bool:
	var mine := _my_level()
	if mine == null:
		return true
	if _run and _run.has_method("get_current_level"):
		var cur: Node = _run.get_current_level()
		if cur:
			return cur == mine
	return true

func _my_level() -> Node2D:
	if _run and _run.has_method("level_of"):
		return _run.level_of(self)
	return get_parent() as Node2D

func _on_hit_invincible_started() -> void:
	if _state == State.VANISH:
		return
	if _was_hitter:
		_state = State.FLEE
		_flee_left = flee_seconds
		_set_nav_target(_flee_point())
	else:
		_start_wander()

func _on_scepter_invincible_started() -> void:
	if _state == State.CHASE:
		_start_wander()

func _on_monsters_redeploy() -> void:
	if freeze or _player == null or _player.is_dead:
		return
	if not _was_hitter:
		return
	_was_hitter = false
	_redeploy()

func _on_hurt_body_entered(body: Node) -> void:
	if body != _player:
		return
	if not _same_level_as_player():
		return
	if _player.is_invincible:
		return
	if not ignores_scepter and _player.scepter_invincible:
		return
	_was_hitter = true
	_player.take_damage()

func _start_wander() -> void:
	_state = State.WANDER
	_exit = null
	_pick_wander_point()

func _pick_next_idle() -> void:
	if randf() < exit_chance:
		var ex := _random_exit()
		if ex:
			_exit = ex
			_state = State.GO_EXIT
			_set_nav_target(ex.global_position)
			return
	_pick_wander_point()

func _pick_wander_point() -> void:
	var p := _random_nav_point()
	_move_target = p
	_set_nav_target(p)

func _random_nav_point() -> Vector2:
	var map_rid: RID = navigation_agent.get_navigation_map()
	if map_rid.is_valid():
		var p: Vector2 = NavigationServer2D.map_get_random_point(map_rid, 1, false)
		if p != Vector2.ZERO:
			return p
	return global_position + Vector2(randf_range(-32.0, 32.0), randf_range(-32.0, 32.0))

func _flee_point() -> Vector2:
	var away := global_position - _player.global_position
	if away.length_squared() < 4.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	return global_position + away.normalized() * 80.0

func _set_nav_target(p: Vector2) -> void:
	_move_target = p
	navigation_agent.target_position = p

func _move_along_path() -> void:
	var next := _move_target
	if not phase_through_walls:
		if navigation_agent.is_navigation_finished():
			velocity = Vector2.ZERO
			move_and_slide()
			return
		next = navigation_agent.get_next_path_position()
	var dir := global_position.direction_to(next)
	velocity = dir * speed
	move_and_slide()

func _update_facing() -> void:
	if body_sprite == null or velocity.x == 0.0:
		return
	var anim := &"normal_right" if velocity.x > 0.0 else &"normal_left"
	if body_sprite.sprite_frames and body_sprite.sprite_frames.has_animation(anim):
		if body_sprite.animation != anim:
			body_sprite.play(anim)

#当前层上填了 target_level 的楼梯/路口
func _random_exit() -> Area2D:
	var level := _my_level()
	var options: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("monster_exit"):
		if not (n is Area2D):
			continue
		var area := n as Area2D
		if str(area.get("target_level")) == "":
			continue
		if level and not _is_under(area, level):
			continue
		options.append(area)
	if options.is_empty():
		return null
	return options.pick_random()

func _is_under(node: Node, level: Node) -> bool:
	var p := node
	while p:
		if p == level:
			return true
		p = p.get_parent()
	return false

func _use_exit(area: Area2D) -> void:
	var dest := str(area.get("target_level"))
	var spawn := str(area.get("spawn_id"))
	if dest == "" or _run == null or not _run.has_method("teleport_actor"):
		_start_wander()
		return
	_run.teleport_actor(self, dest, spawn)
	_start_wander()

#只有打中玩家的那只会走到这里
func _redeploy() -> void:
	_state = State.VANISH
	velocity = Vector2.ZERO
	var zones := _collect_zones()
	if zones.is_empty():
		_start_wander()
		return
	var zone: Area2D = zones.pick_random()
	var dest_level = _run.level_of(zone) if _run and _run.has_method("level_of") else zone.get_parent()
	var pos := _random_point_in_zone(zone)
	if dest_level is Node2D:
		if _run and _run.has_method("teleport_actor"):
			_run.teleport_actor(self, dest_level.name, "")
		elif get_parent() != dest_level:
			reparent(dest_level)
	global_position = pos
	if not phase_through_walls:
		var map_rid: RID = navigation_agent.get_navigation_map()
		if map_rid.is_valid():
			global_position = NavigationServer2D.map_get_closest_point(map_rid, global_position)
	_start_wander()

func _collect_zones() -> Array[Area2D]:
	var out: Array[Area2D] = []
	for n in get_tree().get_nodes_in_group("spawn_zone"):
		if n is Area2D:
			out.append(n)
	return out

func _random_point_in_zone(area: Area2D) -> Vector2:
	for child in area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var r: Vector2 = (child.shape as RectangleShape2D).size * 0.5
			var local := Vector2(randf_range(-r.x, r.x), randf_range(-r.y, r.y))
			return child.global_transform * local
		if child is CollisionPolygon2D and child.polygon.size() >= 3:
			var poly: PackedVector2Array = child.polygon
			var a := poly[0]
			var i := randi_range(1, poly.size() - 2)
			var t := randf()
			var u := randf()
			if t + u > 1.0:
				t = 1.0 - t
				u = 1.0 - u
			var p: Vector2 = a + t * (poly[i] - a) + u * (poly[i + 1] - a)
			return child.global_transform * p
	return area.global_position
