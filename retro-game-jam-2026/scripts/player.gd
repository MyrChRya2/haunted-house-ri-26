extends CharacterBody2D
class_name player
#玩家脚本
#目前实现功能：八向移动，受击，道具

#timer节点
@onready var _invincible_timer: Timer = $Timer
#移动速度
@export var move_speed: float = 120.0

#道具功能，玩家转发到Inventory,修改文件名和路径记得改
@onready var _inventory: HeldItemInventory = $Inventory
const KEY_SCENE := preload("res://item/Key.tscn")
const SCEPTER_SCENE := preload("res://item/Scepter.tscn")
const WENG_SCENE := preload("res://item/Weng.tscn")
const PIECE_SCENE := preload("res://item/Piece.tscn")
const PIECES_SCENE := preload("res://item/Pieces.tscn")
#无敌时间
@export var invincible_seconds : float = 3.0
#无敌剩余时间
var _invincible_left: float = 0.0
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

#八向移动
func _physics_process(delta: float) -> void:
	#生命归零冻结操作
	if is_dead == true:
		return
	#游戏胜利冻结操作
	if is_win == true:
		return
	#受击后无敌时间内不可移动
	if is_invincible == true:
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
	monsters_redeploy.emit()
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
		HeldItemInventory.HeldItem.SCEPTER: return SCEPTER_SCENE
		HeldItemInventory.HeldItem.PIECE:   return PIECE_SCENE        
		HeldItemInventory.HeldItem.PIECES:  return PIECES_SCENE       
		HeldItemInventory.HeldItem.WENG:    return WENG_SCENE
		_:                                  
			return null


#丢下物品，交给floor，让floor记录，进行加载和清除
func _on_item_dropped(kind: HeldItemInventory.HeldItem, count: int) -> void:
	var packed := _drop_scene_of(kind)
	if packed == null:
		return
	var loader = get_tree().get_first_node_in_group("floor_loader")
	loader.register_drop(packed, global_position, current_floor)
#是否点亮火把
func is_lit_at(pos: Vector2) -> bool:
	if _match_light == null:
		return false
	return _match_light.is_position_illuminated(pos)
#点亮状态下可拾取物品
func try_pickup_at(kind: HeldItemInventory.HeldItem, pos: Vector2) -> bool:
	if not is_lit_at(pos):
		return false
	return _inventory.try_pickup(kind)
