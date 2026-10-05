extends Node2D
# 火柴：IgniteFlash 一帧 + VisionMask 乘算遮罩（黑底圆洞），不叠 PointLight

const MASK_SIZE := Vector2(2048, 2048)
const SOFTNESS := 14.0

@onready var _light: PointLight2D = $Light
@onready var _burn_timer: Timer = $BurnTimer
@onready var _ignite_flash: Sprite2D = $IgniteFlash
@onready var _vision_mask: ColorRect = $VisionMask

@export var burn_seconds: float = 3.0
@export var full_radius: float = 64.0
@export var expand_seconds: float = 0.2
@export var shrink_seconds: float = 0.2
## 关卡里的 Scenery 节点（闪光插到它前面）
@export var scenery_path: NodePath = ^"../../Scenery"

var is_lit: bool = false
var matches_used: int = 0
var _current_radius: float = 0.0
var _radius_tween: Tween
var _busy: bool = false

signal match_used

func _ready() -> void:
	show_behind_parent = true
	# 停用 PointLight，避免与 VisionMask 双重变亮
	_light.enabled = false
	_light.energy = 0.0
	_ignite_flash.visible = false
	_ignite_flash.centered = true
	_vision_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vision_mask.size = MASK_SIZE
	_vision_mask.position = -MASK_SIZE * 0.5
	_vision_mask.color = Color.WHITE
	_apply_mask_uniforms()
	_set_radius(0.0)
	_burn_timer.one_shot = true
	if not _burn_timer.timeout.is_connected(_on_burn_timer_timeout):
		_burn_timer.timeout.connect(_on_burn_timer_timeout)
	extinguish(&"init")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("light_match"):
		try_light()

func try_light() -> void:
	if is_lit or _busy:
		return
	_busy = true
	matches_used += 1
	match_used.emit(matches_used)
	is_lit = true
	_kill_radius_tween()
	await _play_ignite_flash()
	_set_radius(0.0)
	_radius_tween = create_tween()
	_radius_tween.tween_method(_set_radius, 0.0, full_radius, expand_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_burn_timer.start(burn_seconds)
	_busy = false

func extinguish(reason: StringName) -> void:
	_busy = false
	is_lit = false
	_burn_timer.stop()
	_kill_radius_tween()
	_ignite_flash.visible = false
	_set_radius(0.0)
	_light.enabled = false
	_light.energy = 0.0

func _on_burn_timer_timeout() -> void:
	_start_shrink()

func _start_shrink() -> void:
	if not is_lit:
		return
	_kill_radius_tween()
	var from := _current_radius
	_radius_tween = create_tween()
	_radius_tween.tween_method(_set_radius, from, 0.0, shrink_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_radius_tween.tween_callback(func() -> void: extinguish(&"burn_out"))

func _play_ignite_flash() -> void:
	var old_parent := _ignite_flash.get_parent()
	var scenery: Node = get_node_or_null(scenery_path)
	if scenery:
		var level := scenery.get_parent()
		var idx := scenery.get_index()
		var gp := global_position
		_ignite_flash.reparent(level)
		level.move_child(_ignite_flash, idx)
		_ignite_flash.global_position = gp
	_ignite_flash.visible = true
	await get_tree().process_frame
	_ignite_flash.visible = false
	if old_parent and is_instance_valid(old_parent):
		_ignite_flash.reparent(old_parent)
		_ignite_flash.position = Vector2.ZERO

func _set_radius(r: float) -> void:
	_current_radius = maxf(r, 0.0)
	_apply_mask_uniforms()

func _apply_mask_uniforms() -> void:
	var mat := _vision_mask.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("radius", _current_radius)
	mat.set_shader_parameter("softness", SOFTNESS)
	mat.set_shader_parameter("rect_size", MASK_SIZE)

func _kill_radius_tween() -> void:
	if _radius_tween != null and _radius_tween.is_valid():
		_radius_tween.kill()
	_radius_tween = null

## 捡道具：用当前遮罩半径（扩圈/缩圈中途也会变）
func is_position_illuminated(global_pos: Vector2) -> bool:
	if not is_lit or _current_radius <= 0.0:
		return false
	return global_position.distance_squared_to(global_pos) <= _current_radius * _current_radius
