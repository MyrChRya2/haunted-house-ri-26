extends Node2D

const LIGHT_LAYER_SCENERY := 1
const LIGHT_LAYER_ITEM := 2
#火把脚本

#都是label节点直接读名字就行
@onready var _light: PointLight2D = $Light

@onready var _burn_timer: Timer = $BurnTimer

@export var burn_seconds: float = 3.0

@export var light_energy: float = 1.2
#点亮范围（可拾取物品）
@export var illuminate_radius: float = 32.0

#火把状态
var is_lit : bool = false
#火把计数器
var matches_used : int = 0

#初始化计时器
func _ready() -> void:
	_light.range_item_cull_mask = LIGHT_LAYER_SCENERY | LIGHT_LAYER_ITEM
	_burn_timer.one_shot = true
	_burn_timer.timeout.connect(_on_burn_timer_timeout)
	extinguish(&"init")

#输入
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("light_match"):
		try_light()
#发出信号并且传出参数，给hub用显示火把计数
signal match_used
#点燃火把
func try_light() -> void:
	if is_lit:#防止重复点燃
		return
	matches_used += 1#火把计数
	match_used.emit(matches_used)
	is_lit = true
	_light.enabled = true
	_light.energy = light_energy
	_burn_timer.start(burn_seconds)  #重置燃烧时间
	

# 熄灭，参数是原因，后期引入多种熄灭方式，与怪物同房间/吹灭
func extinguish(reason: StringName) -> void:
	is_lit = false
	_burn_timer.stop()  # 防止中途熄灭还会再 timeout 一次
	_light.enabled = false
	_light.energy = 0.0


func _on_burn_timer_timeout() -> void:
	extinguish(&"burn_out")


## 某全局坐标是否在光照逻辑半径内（以后捡东西用）
func is_position_illuminated(global_pos: Vector2) -> bool:
	if not is_lit:
		return false
	return global_position.distance_squared_to(global_pos) <= illuminate_radius * illuminate_radius
