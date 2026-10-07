extends Node2D
# 火柴：IgniteFlash 火花闪一下 + VisionMask 乘算遮罩（序列帧贴图挖洞），不叠 PointLight
# 点火：正序播一遍并停在最后一帧；燃烧：保持最后一帧；熄灭：倒序播回第 1 帧后全黑

const MASK_SIZE := Vector2(2048, 2048)

enum Phase { DARK, FLASH, IGNITING, BURNING, FADING }

@onready var _light: PointLight2D = $Light
@onready var _burn_timer: Timer = $BurnTimer
@onready var _ignite_flash: Sprite2D = $IgniteFlash
@onready var _vision_mask: ColorRect = $VisionMask

@export var burn_seconds: float = 5.0
#光圈半径（像素），一格序列帧铺满这个直径
@export var full_radius: float = 64.0
#火把持续时间
@export var flash_seconds: float = 0.05
#遮罩序列帧图：所有帧横排一行，白透黑不透
@export var mask_sheet: Texture2D
#序列帧帧数
@export var hframes: int = 5
#每秒播放帧数
@export var mask_fps: float = 12.0


var is_lit: bool = false
var matches_used: int = 0
var _current_radius: float = 0.0
var _busy: bool = false
var _phase: Phase = Phase.DARK
var _frame_time: float = 0.0
var _frame: int = 0

signal match_used(count: int)
#开始燃烧信号
signal burn_started

func _ready() -> void:
	show_behind_parent = true
	#停用PointLight，避免与VisionMask双重变亮
	_light.enabled = false
	_light.energy = 0.0
	_ignite_flash.visible = false
	_ignite_flash.centered = true
	_ignite_flash.position = Vector2.ZERO
	#火花画在遮罩上面：黑底上亮一下，墙不挡它
	move_child(_ignite_flash, _vision_mask.get_index())
	_vision_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vision_mask.size = MASK_SIZE
	_vision_mask.position = -MASK_SIZE * 0.5
	_vision_mask.color = Color.WHITE
	_init_mask_material()
	_burn_timer.one_shot = true
	if not _burn_timer.timeout.is_connected(_on_burn_timer_timeout):
		_burn_timer.timeout.connect(_on_burn_timer_timeout)
	extinguish(&"init")


func _process(delta: float) -> void:
	if _phase != Phase.IGNITING and _phase != Phase.FADING:
		return
	_frame_time += delta
	var last := _last_frame()
	var steps := last + 1 if mask_fps <= 0.0 else int(_frame_time * mask_fps)
	if _phase == Phase.IGNITING:
		if steps >= last:
			_set_frame(last)
			_phase = Phase.BURNING
			_busy = false
			_burn_timer.start(burn_seconds)
			burn_started.emit()
		else:
			_set_frame(steps)
	else:
		if steps > last:
			extinguish(&"burn_out")
		else:
			_set_frame(last - steps)

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
	_phase = Phase.FLASH
	await _play_ignite_flash()
	if not is_lit:
	#闪光这一帧里被extinguish了
		return 
	_reset_frames()
	_set_radius(full_radius)
	_phase = Phase.IGNITING

func extinguish(reason: StringName) -> void:
	_busy = false
	is_lit = false
	_phase = Phase.DARK
	_burn_timer.stop()
	_ignite_flash.visible = false
	_reset_frames()
	_set_radius(0.0)
	_light.enabled = false
	_light.energy = 0.0

func _on_burn_timer_timeout() -> void:
	if _phase != Phase.BURNING:
		return
	 #倒放期间不能点下一根
	_busy = true
	_frame_time = 0.0
	_phase = Phase.FADING

func _play_ignite_flash() -> void:
	_ignite_flash.visible = true
	await get_tree().create_timer(maxf(flash_seconds, 0.0), false).timeout
	_ignite_flash.visible = false

func _last_frame() -> int:
	return maxi(hframes, 1) - 1

func _set_radius(r: float) -> void:
	_current_radius = maxf(r, 0.0)
	var mat := _vision_mask.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("radius", _current_radius)

#图，帧数，遮罩尺寸只在ready传一次
func _init_mask_material() -> void:
	var mat := _vision_mask.material as ShaderMaterial
	if mat == null:
		push_warning("MatchLight: VisionMask 没有 ShaderMaterial")
		return
	if mask_sheet == null:
		push_warning("MatchLight: 没有设置 mask_sheet，点火后会是全黑")
	elif mask_sheet.get_width() != maxi(hframes, 1) * mask_sheet.get_height():
		push_warning("MatchLight: mask_sheet 宽 %d 不等于 帧数 %d × 高 %d，光圈会切歪" % [mask_sheet.get_width(), hframes, mask_sheet.get_height()])
	mat.set_shader_parameter("mask_tex", mask_sheet)
	mat.set_shader_parameter("hframes", maxi(hframes, 1))
	mat.set_shader_parameter("rect_size", MASK_SIZE)
	_set_frame(0)
	_set_radius(_current_radius)

func _set_frame(f: int) -> void:
	_frame = f
	var mat := _vision_mask.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("frame", f)

#每根新火柴都从第 1 帧开始
func _reset_frames() -> void:
	_frame_time = 0.0
	_set_frame(0)

#捡道具：只有停在最后一帧的燃烧期间算照亮，正放和倒放时不算
func is_position_illuminated(global_pos: Vector2) -> bool:
	if _phase != Phase.BURNING or _current_radius <= 0.0:
		return false
	return global_position.distance_squared_to(global_pos) <= _current_radius * _current_radius
