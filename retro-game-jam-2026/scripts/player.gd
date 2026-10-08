extends CharacterBody2D
class_name player

@onready var _invincible_timer: Timer = $Timer
@export var move_speed: float = 55.0

#道具功能，玩家转发到Inventory
@onready var _inventory: HeldItemInventory = $Inventory
const KEY_SCENE := preload("res://item/key.tscn")
const SHILD_SCENE := preload("res://item/Shild.tscn")
const WENG_SCENE := preload("res://item/Weng.tscn")
const PIECEM_SCENE := preload("res://item/piece_m.tscn")
const PIECES_SCENE := preload("res://item/Pieces.tscn")
const PIECEL_SCENE := preload("res://item/piece_l.tscn")
const PIECER_SCENE := preload("res://item/piece_r.tscn")
#无敌时间
@export var invincible_seconds : float = 3.0
#受击无敌闪烁间隔
@export var hit_blink_interval: float = 0.1
#无敌剩余时间
var _invincible_left: float = 0.0
var _blink_t: float = 0.0
#无敌状态
var is_invincible : bool = false
#权杖无敌
var scepter_invincible : bool = false

#生命
@export var lives : int = 3
@export var max_lives : int = 5
#生命值变化广播
signal lives_changed(current: int)
#死亡状态
var is_dead : bool = false
#死亡信号
signal player_dead()
signal hit_invincible_started()
signal scepter_invincible_started()
signal monsters_redeploy()

#楼层
var current_floor: int = 1
var _stair_cooldown: float = 0.0
const FLOOR_MIN := 1
const FLOOR_MAX := 4

#游戏胜利
var is_win = false
#动画节点
@onready var _shild: AnimatedSprite2D = $Shild
@onready var body_sprite: AnimatedSprite2D = $BodySprite
#动画名前缀
const NORMAL_ANIMATION_PREFIX := &"normal"
#后缀
var facing_suffix := &"right"
#受击动画名（美术给了 hit 就自动播；没给就只靠闪烁表示受击）
const HIT_ANIMATION := &"hit"

@onready var _match_light: Node = $MatchLight
#走路 / 受击 / 碰墙
@onready var _sfx_walk: AudioStreamPlayer = $walk
@onready var _sfx_hit: AudioStreamPlayer = $hit
@onready var _sfx_wall: AudioStreamPlayer = $wall
#拾取 / 一滴血 / 合成
@onready var _sfx_pickup: AudioStreamPlayer = $pickup
@onready var _sfx_low_life: AudioStreamPlayer = $low_life
@onready var _sfx_craft_pieces: AudioStreamPlayer = $craft_pieces
@onready var _sfx_craft_weng: AudioStreamPlayer = $craft_weng
var _wall_sfx_on: bool = false
#走路音效上次停下的位置
var _walk_resume: float = 0.0

func _ready() -> void:
	#timer初始化
	_invincible_timer.one_shot = true
	_invincible_timer.timeout.connect(_on_invincible_seconds)
#物品掉落信号
	_inventory.item_dropped.connect(_on_item_dropped)
#权杖无敌信号
	_inventory.invincible_apply.connect(scepter_invincible_apply)
	_inventory.invincible_exit.connect(scepter_invincible_exit)
#合成 pieces / weng 加一格血
	_inventory.pieces_crafted.connect(add_life)
	_inventory.weng_crafted.connect(add_life)
#拾取道具 / 两片合成 / 三片合成 各一个音效
	_inventory.item_taken.connect(_on_item_taken_sfx)
	_inventory.pieces_crafted.connect(_on_craft_pieces_sfx)
	_inventory.weng_crafted.connect(_on_craft_weng_sfx)
#加组
	add_to_group("player")
	hit_invincible_started.connect(_on_hit_fx)
	#受击动画播完要接回朝向动画
	if body_sprite and not body_sprite.animation_finished.is_connected(_on_body_anim_finished):
		body_sprite.animation_finished.connect(_on_body_anim_finished)
	#走路音效要一直响：素材没开循环就在这里补上
	_ensure_loop(_sfx_walk)
	_udpdate_animation()
#火光烧完重新点亮时重新判定脚下道具
	if _match_light and _match_light.has_signal("burn_started"):
		_match_light.burn_started.connect(_recheck_pickups)
#受击闪烁
func _process(delta: float) -> void:
	#传送时物理帧被关掉，走路音效要在这里收尾
	if not is_physics_processing():
		_stop_move_sfx()
	if is_invincible and not is_dead:
		_blink_t += delta
		if _blink_t >= hit_blink_interval:
			_blink_t = 0.0
			body_sprite.visible = not body_sprite.visible
	else:
		_stop_hit_blink()

#八向移动
func _physics_process(delta: float) -> void:
	#生命归零 / 胜利 / 受击无敌：站住，但仍要 move_and_slide 把碰撞结算掉
	if is_dead or is_win or is_invincible:
		velocity = Vector2.ZERO
		move_and_slide()
		_stop_move_sfx()
		return
	var move_input := Input.get_vector("move_left","move_right","move_up","move_down")
	velocity = move_speed* move_input
	move_and_slide()
	_update_move_sfx(move_input)
	#楼层
	if _stair_cooldown > 0.0:
		_stair_cooldown -= delta
	if move_input != Vector2.ZERO:
		facing_suffix =_vector_to_facing_suffix(move_input)
	_udpdate_animation()

#动画实现
#前后缀拼出动画名
func _udpdate_animation()->void:
	var animation_name := StringName("%s_%s" % [NORMAL_ANIMATION_PREFIX, facing_suffix])

	if not body_sprite.sprite_frames.has_animation(animation_name):
		push_warning("Missing player animation: %s" % animation_name)
		return
	if body_sprite.animation != animation_name:
		body_sprite.play(animation_name)

func _vector_to_facing_suffix (direction: Vector2) -> StringName:
	if abs(direction.x) >= abs(direction.y):
		return &"right" if direction.x > 0.0 else &"left"
		
	return &"down" if direction.y > 0.0 else &"up"

#拿权杖开护盾动画，放下关掉
func shild():
	if _shild == null:
		return
	_shild.visible = scepter_invincible
	if scepter_invincible:
		_shild.play(&"shild")



#改变状态
func win():
	is_win = true

#合成加血，不超过上限
func add_life() -> void:
	if is_dead or lives >= max_lives:
		return
	lives += 1
	lives_changed.emit(lives)

#受击掉血
func take_damage() -> void:
	if is_invincible :
		return
	#防止血量低于0
	if is_dead == true:
		return
	if scepter_invincible == true:
		return
	is_invincible = true
	_invincible_left = invincible_seconds
	_blink_t = 0.0
	body_sprite.visible = false
	lives -= 1
	#只剩一滴血
	if lives == 1:
		_play_sfx(_sfx_low_life, true)
	#死亡
	if lives <= 0:
		is_dead = true
		_stop_move_sfx()
		player_dead.emit()
	#ui用，接受这个信号改变血量
	lives_changed.emit(lives)#广播掉血信号
	_invincible_timer.start(invincible_seconds)
	hit_invincible_started.emit()
#退出无敌
func invincible_out() -> void:
	is_invincible = false
	_stop_hit_blink()
	monsters_redeploy.emit()

#受击音效，有受击动画就播
func _on_hit_fx() -> void:
	_play_sfx(_sfx_hit, true)
	if _has_frames(HIT_ANIMATION):
		body_sprite.play(HIT_ANIMATION)

#受击动画播完（不循环）接回当前朝向的动画
func _on_body_anim_finished() -> void:
	if body_sprite.animation == HIT_ANIMATION:
		_udpdate_animation()

#这套 SpriteFrames 里这个动画有没有真帧（有动画名但零帧＝播不了）
func _has_frames(anim: StringName) -> bool:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return false
	return body_sprite.sprite_frames.has_animation(anim) and body_sprite.sprite_frames.get_frame_count(anim) > 0

#走路音效必须连续响：素材没开循环就在这里补上
func _ensure_loop(sfx: AudioStreamPlayer) -> void:
	if sfx == null or sfx.stream == null:
		return
	if sfx.stream is AudioStreamWAV:
		var w := sfx.stream as AudioStreamWAV
		#只有 PCM 算得出采样数；adpcm / qoa 不动
		var bytes_per_sample := 0
		match w.format:
			AudioStreamWAV.FORMAT_8_BITS:
				bytes_per_sample = 1
			AudioStreamWAV.FORMAT_16_BITS:
				bytes_per_sample = 2
			_:
				return
		var samples := w.data.size() / bytes_per_sample
		if w.stereo:
			samples /= 2
		if samples <= 0:
			return
		#loop_begin/loop_end 单位是采样数；两个都留 0 的话这段音频根本播不出来（实测）
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples
	elif sfx.stream is AudioStreamOggVorbis:
		(sfx.stream as AudioStreamOggVorbis).loop = true
	elif sfx.stream is AudioStreamMP3:
		(sfx.stream as AudioStreamMP3).loop = true

#拾取道具（捡起 / 换手 / 拿到 weng 都会发）
func _on_item_taken_sfx(_kind: int) -> void:
	_play_sfx(_sfx_pickup, true)

#两片合成 pieces
func _on_craft_pieces_sfx() -> void:
	_play_sfx(_sfx_craft_pieces, true)

#三片合成 weng
func _on_craft_weng_sfx() -> void:
	_play_sfx(_sfx_craft_weng, true)

#停走路音效但记住播到哪，擦墙后接着播、不重头响
func _stop_walk_sfx() -> void:
	if _sfx_walk and _sfx_walk.playing:
		_walk_resume = _sfx_walk.get_playback_position()
		_sfx_walk.stop()

#有输入：走路循环；顶墙改碰墙；停下/死亡停掉
func _update_move_sfx(move_input: Vector2) -> void:
	var moving := move_input != Vector2.ZERO
	var hitting_wall := moving and get_slide_collision_count() > 0
	if hitting_wall:
		_stop_walk_sfx()
		if not _wall_sfx_on:
			_play_sfx(_sfx_wall, true)
			_wall_sfx_on = true
		return
	_wall_sfx_on = false
	_stop_sfx(_sfx_wall)
	if moving:
		#接着上次停下的位置播，擦墙后不会重头响
		if _sfx_walk and _sfx_walk.stream and not _sfx_walk.playing:
			_sfx_walk.play(_walk_resume)
	else:
		_stop_walk_sfx()
		_walk_resume = 0.0

func _stop_move_sfx() -> void:
	_wall_sfx_on = false
	_walk_resume = 0.0
	_stop_sfx(_sfx_walk)
	_stop_sfx(_sfx_wall)

func _play_sfx(sfx: AudioStreamPlayer, restart: bool) -> void:
	if sfx == null or sfx.stream == null:
		return
	if restart or not sfx.playing:
		sfx.play()

func _stop_sfx(sfx: AudioStreamPlayer) -> void:
	if sfx and sfx.playing:
		sfx.stop()

func _stop_hit_blink() -> void:
	_blink_t = 0.0
	if body_sprite and not body_sprite.visible:
		body_sprite.visible = true
#无敌时间归0
func _on_invincible_seconds () -> void:
	invincible_out()
#权杖用代码，拾取权杖改变状态
func scepter_invincible_apply():
	scepter_invincible = true
	scepter_invincible_started.emit()
	shild()
func scepter_invincible_exit():
	scepter_invincible = false
	shild()

#楼层变化广播
signal floor_changed(current: int)

#上下楼
func try_use_stair(delta: int) -> bool:
	if _stair_cooldown > 0.0:
		return false
	var next := clampi(current_floor + delta, FLOOR_MIN, FLOOR_MAX)
	if next == current_floor:
		return false

	current_floor = next
	_stair_cooldown = 0.25
	floor_changed.emit(current_floor)
	return true


#询问是否有钥匙开门用
func has_key() -> bool:
	return _inventory.has_key()

func get_held() -> HeldItemInventory.HeldItem:
	return _inventory.get_held()
#询问是否有weng，通关用
func has_weng() -> bool:
	return _inventory.has_weng()

#拾取另一个道具的时候放下手上的道具
func _drop_scene_of(kind: HeldItemInventory.HeldItem) -> PackedScene:
	match kind:
		HeldItemInventory.HeldItem.KEY:     return KEY_SCENE
		HeldItemInventory.HeldItem.SCEPTER: return SHILD_SCENE
		HeldItemInventory.HeldItem.PIECEM:  return PIECEM_SCENE
		HeldItemInventory.HeldItem.PIECEL:  return PIECEL_SCENE
		HeldItemInventory.HeldItem.PIECER:  return PIECER_SCENE
		HeldItemInventory.HeldItem.PIECES:  return PIECES_SCENE
		HeldItemInventory.HeldItem.WENG:    return WENG_SCENE
		_:                                  
			return null


#丢下物品
func _on_item_dropped(kind: HeldItemInventory.HeldItem, _count: int) -> void:
	var packed := _drop_scene_of(kind)
	if packed == null:
		return
	var node: Node2D = packed.instantiate()
	if "wait_leave" in node:
		node.wait_leave = true
	get_parent().add_child(node)
	node.global_position = global_position
func is_lit_at(pos: Vector2) -> bool:
	if _match_light == null:
		return false
	return _match_light.is_position_illuminated(pos)
#点亮状态下可拾取物品
func try_pickup_at(kind: HeldItemInventory.HeldItem, pos: Vector2) -> bool:
	if not is_lit_at(pos):
		return false
	return _inventory.try_pickup(kind)

#点火前就站在道具上，火光烧满时补捡一次（只捡一个）
func _recheck_pickups() -> void:
	for item in get_tree().get_nodes_in_group("pickup"):
		if item is Area2D and item.overlaps_body(self) and item.has_method("_on_body_entered"):
			item._on_body_entered(self)
			if item.is_queued_for_deletion():
				return
