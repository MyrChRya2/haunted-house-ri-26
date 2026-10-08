extends CanvasLayer
#蒙版动画
#一帧就是一屏
const FRAME_W := 192          
const FRAME_H := 160
#序列帧张数
const FRAME_COUNT := 21       
#每帧停留秒数
const FRAME_SEC := 0.03       
#序列帧贴图
@export var sheet: Texture2D
@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	#死亡结算会把整棵树暂停
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	visible = false 
	_sprite.centered = true
	_sprite.position = Vector2(FRAME_W, FRAME_H) * 0.5
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sheet:
		_sprite.texture = sheet
	_sprite.hframes = FRAME_COUNT
	_sprite.vframes = 1
	_sprite.frame = 0

#盖幕：全透明 → 全黑
func play_cover(move: Vector2) -> void:
	_apply_move(move)
	_play_dir_sfx(move)
	visible = true
	await _play(0, FRAME_COUNT - 1)

#揭幕：全黑 → 全透明，播完自动隐藏
func play_reveal(move: Vector2) -> void:
	_apply_move(move)
	visible = true
	await _play(FRAME_COUNT - 1, 0)
	visible = false

#进门方向分类
func dir_of(move: Vector2) -> StringName:
	if move.length_squared() < 1.0:
		return &""
	if absf(move.x) >= absf(move.y):
		return &"left" if move.x < 0.0 else &"right"
	return &"up" if move.y < 0.0 else &"down"

#画面转向
func _apply_move(move: Vector2) -> void:
	#每次都先复位，连续转场才不会累积变形
	_sprite.flip_h = false
	_sprite.flip_v = false
	_sprite.rotation_degrees = 0.0
	_sprite.scale = Vector2.ONE
	var cover_scale := FRAME_W / float(FRAME_H)
	match dir_of(move):
		&"down":
			_sprite.flip_v = true
		&"left":
			_sprite.rotation_degrees = 90.0
			_sprite.scale = Vector2(cover_scale, cover_scale)
		&"right":
			_sprite.rotation_degrees = -90.0
			_sprite.scale = Vector2(cover_scale, cover_scale)

#方向音效：上下一段，左右一段
func _play_dir_sfx(move: Vector2) -> void:
	var sfx: AudioStreamPlayer = null
	match dir_of(move):
		&"up", &"down":
			sfx = $sfx_vertical
		&"left", &"right":
			sfx = $sfx_horizontal
	if sfx and sfx.stream:
		sfx.play()


#正倒序播放
func _play(from_frame: int, to_frame: int) -> void:
	#正序 step=+1、倒序 step=-1
	var step := 1 if to_frame >= from_frame else -1
	var i := from_frame
	while true:
		_sprite.frame = i
		if i == to_frame:
			break
		await get_tree().create_timer(FRAME_SEC, true).timeout
		i += step
