extends CanvasLayer
#蒙版动画
#按进门时的移动向量播 GIF：上正序、下倒序、左右转 90°
const FRAME_W := 192
const FRAME_H := 160
const FRAME_COUNT := 21
const FRAME_SEC := 0.03

@export var sheet: Texture2D
@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
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

func play_cover(move: Vector2) -> void:
	_apply_move(move)
	visible = true
	await _play(0, FRAME_COUNT - 1)

func play_reveal(move: Vector2) -> void:
	_apply_move(move)
	visible = true
	await _play(FRAME_COUNT - 1, 0)
	visible = false

func _apply_move(move: Vector2) -> void:
	_sprite.flip_h = false
	_sprite.flip_v = false
	_sprite.rotation_degrees = 0.0
	_sprite.scale = Vector2.ONE
	if move.length_squared() < 1.0:
		return
	if absf(move.x) >= absf(move.y):
		var cover_scale := FRAME_W / float(FRAME_H)
		_sprite.rotation_degrees = 90.0 if move.x < 0.0 else -90.0
		_sprite.scale = Vector2(cover_scale, cover_scale)
	elif move.y > 0.0:
		_sprite.flip_v = true
#播放
func _play(from_frame: int, to_frame: int) -> void:
	var step := 1 if to_frame >= from_frame else -1
	var i := from_frame
	while true:
		_sprite.frame = i
		if i == to_frame:
			break
		await get_tree().create_timer(FRAME_SEC, true).timeout
		i += step
