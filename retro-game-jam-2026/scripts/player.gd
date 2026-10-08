extends CharacterBody2D
class_name player

@onready var _invincible_timer: Timer = $Timer
@export var move_speed: float = 80.0

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
@export var lives : int = 2
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

@onready var _match_light: Node = $MatchLight

func _ready() -> void:
	#timer初始化
	_invincible_timer.one_shot = true
	_invincible_timer.timeout.connect(_on_invincible_seconds)
#物品掉落信号
	_inventory.item_dropped.connect(_on_item_dropped)
#权杖无敌信号
	_inventory.invincible_apply.connect(scepter_invincible_apply)
	_inventory.invincible_exit.connect(scepter_invincible_exit)
#加组
	add_to_group("player")
	_udpdate_animation()
#火光烧完重新点亮时重新判定脚下道具
	if _match_light and _match_light.has_signal("burn_started"):
		_match_light.burn_started.connect(_recheck_pickups)
#受击闪烁
func _process(delta: float) -> void:
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
		return
	var move_input := Input.get_vector("move_left","move_right","move_up","move_down")
	velocity = move_speed* move_input
	move_and_slide()
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

func shild():
	if scepter_invincible == true:
		_shild.visible = true
	if scepter_invincible == false:
		_shild.visible = false
	pass



#改变状态
func win():
	is_win = true

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
	#死亡
	if lives <= 0:
		is_dead = true
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
func scepter_invincible_exit():
	scepter_invincible = false

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
