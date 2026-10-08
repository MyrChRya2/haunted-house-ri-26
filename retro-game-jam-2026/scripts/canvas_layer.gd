extends CanvasLayer
#hub脚本
#楼层计数废弃
#gameover和youlose直接隐藏，懒得删了
#结算文案
const RESULT_TITLE_WIN := "You Win"
const RESULT_TITLE_LOSE := "You Lose"
const RESULT_MESSAGE_WIN := "Escape successful！"
const RESULT_MESSAGE_LOSE := "You can never leave！"
const RESULT_OK_BUTTON_TEXT := "return"

#血量，三格同一张图
@onready var lives_row: HBoxContainer = $Lives
@export var heart_tex: Texture2D
#楼层
#@onready var floor: Label = $Floor
#结算弹窗
@onready var result_dialog: AcceptDialog = $AcceptDialog
#发出信号的节点
@onready var victory: Node = get_tree().get_first_node_in_group("victory")
#道具图标显示节点
@onready var item_icon: TextureRect = $ItemIcon
#道具图片枚举
@export var item_icons: Array[Texture2D] = []
#道具动画枚举
@export var item_frames: Array[SpriteFrames] = []
#播放的动画名
@export var item_anim: StringName = &"default"
#火把计数器
@onready var matchuse: Label = $match

#玩家节点，在ready中通过get_tree获取
var _player: Node
#仓库节点（拾取道具系统）,通过玩家子节点获得
var _inv: Node = null
#火把节点,通过玩家子节点获得
var _match: Node
#当前图标在播的动画、帧号、计时
var _anim_frames: SpriteFrames = null
var _anim_index := 0
var _anim_time := 0.0

#获取player组里面的player节点，监听lives_changed信号，显示初始生命
func _ready() -> void:
	set_process(false)
	_configure_result_dialog()
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("player 组里没有节点：检查 Player 是否加入 player 组")
		return
	_player.lives_changed.connect(_on_lives_changed)
	_refresh_lives(_player.lives)
	#监听floor_changed信号，显示初始楼层
	#_player.floor_changed.connect(_on_floor_changed)
	#floor.text = "Floor: %d" % _player.current_floor
	#道具初始化
	if _player and _player.has_node("Inventory"):
		var inv = _player.get_node("Inventory")
	#玩家死亡信号
	_player.player_dead.connect(over)
	#显示道具图标初始化
	if _player.has_node("Inventory"):
		_inv = _player.get_node("Inventory")
		#连接道具变化和离手信号
		_inv.held_changed.connect(_on_held_changed)
		_inv.item_dropped.connect(_on_item_dropped)
		_sync_item_icon()
	#获取火把节点
	if _player.has_node("MatchLight"):
		_match = _player.get_node("MatchLight")
		#连接火把信号
		_match.match_used.connect(match_used_count)
#更新血量：剩几格亮几格
func _on_lives_changed(current: int) -> void:
	_refresh_lives(current)

func _refresh_lives(current: int) -> void:
	var i := 0
	for heart in lives_row.get_children():
		if not (heart is TextureRect):
			continue
		var slot := heart as TextureRect
		if heart_tex:
			slot.texture = heart_tex
		slot.visible = i < current
		i += 1
#func _on_floor_changed(current_f: int) -> void:
	#if _player == null:
		#return
	#floor.text = "Floor: %d" % current_f

#配置结算弹窗，暂停时也能点，显示全由代码管
func _configure_result_dialog() -> void:
	result_dialog.dialog_close_on_escape = false
	result_dialog.ok_button_text = RESULT_OK_BUTTON_TEXT
	result_dialog.hide()
	if not result_dialog.confirmed.is_connected(_on_result_dialog_exit_requested):
		result_dialog.confirmed.connect(_on_result_dialog_exit_requested)
	if not result_dialog.close_requested.is_connected(_on_result_dialog_exit_requested):
		result_dialog.close_requested.connect(_on_result_dialog_exit_requested)
	if not result_dialog.canceled.is_connected(_on_result_dialog_exit_requested):
		result_dialog.canceled.connect(_on_result_dialog_exit_requested)

#弹出结算
func _show_result(won: bool) -> void:
	if result_dialog.visible:
		return
	result_dialog.title = RESULT_TITLE_WIN if won else RESULT_TITLE_LOSE
	result_dialog.dialog_text = RESULT_MESSAGE_WIN if won else RESULT_MESSAGE_LOSE
	get_tree().paused = true
	result_dialog.popup_centered()

#结束游戏回标题
func _on_result_dialog_exit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/Start.tscn")

#gameover
func over() -> void:
	if _player == null:
		return
	_show_result(false)

#youwin
func youwin() -> void:
	if _player == null:
		return
	_show_result(true)

#显示道具图标
func _on_held_changed(_old_kind: int, _new_kind: int) -> void:
	_sync_item_icon()

func _on_item_dropped(_kind: int, _count: int) -> void:
	_sync_item_icon()

#从背包读状态
func _sync_item_icon() -> void:
	if _inv == null:
		return
	var kind: int = _inv.get_held()
	_anim_frames = null
	_anim_index = 0
	_anim_time = 0.0
	if kind >= 0 and kind < item_frames.size():
		var sf: SpriteFrames = item_frames[kind]
		if sf and sf.has_animation(item_anim) and sf.get_frame_count(item_anim) > 0:
			_anim_frames = sf
	var tex: Texture2D = null
	if _anim_frames:
		tex = _anim_frames.get_frame_texture(item_anim, 0)
	elif kind >= 0 and kind < item_icons.size():
		tex = item_icons[kind]
	item_icon.texture = tex
	item_icon.visible = (tex != null)
	#只有一帧以上才需要逐帧播放
	set_process(_anim_frames != null and _anim_frames.get_frame_count(item_anim) > 1)

#按SpriteFrames的fps和每帧时长给图标换帧
func _process(delta: float) -> void:
	if _anim_frames == null:
		set_process(false)
		return
	var fps: float = _anim_frames.get_animation_speed(item_anim)
	var count: int = _anim_frames.get_frame_count(item_anim)
	if fps <= 0.0 or count <= 1:
		return
	_anim_time += delta
	var dur: float = _anim_frames.get_frame_duration(item_anim, _anim_index) / fps
	while _anim_time >= dur:
		_anim_time -= dur
		if _anim_index + 1 >= count:
			if not _anim_frames.get_animation_loop(item_anim):
				set_process(false)
				break
			_anim_index = 0
		else:
			_anim_index += 1
		dur = _anim_frames.get_frame_duration(item_anim, _anim_index) / fps
	item_icon.texture = _anim_frames.get_frame_texture(item_anim, _anim_index)
#火把使用数显示
func match_used_count(matches_used):
	matchuse.text = "%d" % matches_used
