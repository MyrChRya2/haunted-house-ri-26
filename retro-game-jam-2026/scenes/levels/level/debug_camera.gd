extends Camera2D
#容器调试总览：F3 切换。火把遮罩在总览时关掉，否则 2048 黑遮罩会盖住全图

@export var room_size: Vector2 = Vector2(192, 160)
@export var padding: float = 1.08

var _overview: bool = false
var _player_cam: Camera2D
var _match: Node2D

func _ready() -> void:
	enabled = false
	set_process_input(true)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_player_cam = player.get_node_or_null("Camera2D") as Camera2D
		_match = player.get_node_or_null("MatchLight") as Node2D

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	#F3：编辑器里 F1 经常到不了游戏
	if key.keycode == KEY_F3 or key.physical_keycode == KEY_F3:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_overview = not _overview
	if _overview:
		_fit_all_maps()
		if _match:
			_match.visible = false
		enabled = true
		make_current()
	else:
		enabled = false
		if _match:
			_match.visible = true
		if _player_cam:
			_player_cam.enabled = true
			_player_cam.make_current()

func _fit_all_maps() -> void:
	var levels := get_parent().get_node_or_null("Levels") as Node2D
	if levels == null or levels.get_child_count() == 0:
		push_warning("DebugCamera: 找不到 Levels")
		return
	var rect := Rect2()
	var first := true
	for child in levels.get_children():
		if not (child is Node2D):
			continue
		var piece := Rect2((child as Node2D).global_position, room_size)
		if first:
			rect = piece
			first = false
		else:
			rect = rect.merge(piece)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	global_position = rect.get_center()
	var view := get_viewport_rect().size
	var z: float = minf(view.x / rect.size.x, view.y / rect.size.y) / padding
	zoom = Vector2(z, z)
