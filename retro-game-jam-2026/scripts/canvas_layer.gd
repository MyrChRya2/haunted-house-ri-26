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

const normal = &"normal"
const broken = &"broken"
const heal = &"heal"


#@export var heart_tex: Texture2D
##生命精灵图：上面一排是扣血动画、下面一排是回血动画（给了它就用它，没给就退回上面那张单图）
#@export var heart_sheet: Texture2D
##一格多少像素，列数/行数按图片尺寸自动算
#@export var heart_frame_size: Vector2i = Vector2i(8, 8)
##生命动画速度（帧/秒）
#@export var heart_fps: float = 12.0
#楼层
#@onready var floor: Label = $Floor
##结算弹窗
#@onready var result_dialog: AcceptDialog = $AcceptDialog
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
#每一格生命：贴图区域 + 正在播的行/帧/计时（行 0=扣血排 1=回血排，-1=不播）
#var _heart_atlas: Array[AtlasTexture] = []
#var _heart_row: Array[int] = []
#var _heart_col: Array[int] = []
#var _heart_time: Array[float] = []
#var _heart_cols: int = 1
#var _heart_rows: int = 1
var lives_row: Array[AnimatedSprite2D] = []
@onready var lives: HBoxContainer = $Lives
var _lives_shown: int = -1

#获取player组里面的player节点，监听lives_changed信号，显示初始生命
func _ready() -> void:
	#set_process(false)
	#_configure_result_dialog()
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("player 组里没有节点：检查 Player 是否加入 player 组")
		return
	_player.lives_changed.connect(_on_lives_changed)
	#_collect_hearts(lives_row)
	_collect_hearts()
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

#更新血量：掉血那格播上排、回血那格播下排，其余按"满/空"静止摆好
func _refresh_lives(current: int) -> void:
	var prev := _lives_shown
	_lives_shown = current
	#var last_col: int = _heart_cols - 1
	#有精灵图才画得出"空格子"，否则退回"剩几格亮几格"
	#var show_empty: bool = heart_sheet != null and _heart_rows >= 2
	for i in lives_row.size():
		var lit: bool = i < current
		var heart: = lives_row[i]
		#var slot := lives_row.get_child(i) as TextureRect
		#if slot:
			#slot.visible = lit or show_empty

		var changed: bool = prev >= 0 and i >= mini(prev, current) and i < maxi(prev, current)
		if changed:
			heart.visible = true
			if current > prev:
				heart.stop()
				heart.play(heal)
			else:
				heart.stop()
				heart.play(broken)
		elif lit:
			heart.visible = true
			heart.stop()
			heart.play(normal)
		else:
			heart.visible = false
	set_process(true)
#func _on_floor_changed(current_f: int) -> void:
	#if _player == null:
		#return
	#floor.text = "Floor: %d" % current_f

##配置结算弹窗，暂停时也能点，显示全由代码管
#func _configure_result_dialog() -> void:
	#result_dialog.dialog_close_on_escape = false
	#result_dialog.ok_button_text = RESULT_OK_BUTTON_TEXT
	#result_dialog.hide()
	#if not result_dialog.confirmed.is_connected(_on_result_dialog_exit_requested):
		#result_dialog.confirmed.connect(_on_result_dialog_exit_requested)
	#if not result_dialog.close_requested.is_connected(_on_result_dialog_exit_requested):
		#result_dialog.close_requested.connect(_on_result_dialog_exit_requested)
	#if not result_dialog.canceled.is_connected(_on_result_dialog_exit_requested):
		#result_dialog.canceled.connect(_on_result_dialog_exit_requested)

##弹出结算
#func _show_result(won: bool) -> void:
	#if result_dialog.visible:
		#return
	#result_dialog.title = RESULT_TITLE_WIN if won else RESULT_TITLE_LOSE
	#result_dialog.dialog_text = RESULT_MESSAGE_WIN if won else RESULT_MESSAGE_LOSE
	#get_tree().paused = true
	#result_dialog.popup_centered()

#结束游戏回标题
#func _on_result_dialog_exit_requested() -> void:
	#get_tree().paused = false
	#get_tree().change_scene_to_file("res://ui/Start.tscn")

#gameover
func over() -> void:
	if _player == null:
		return
	#_show_result(false)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://ui/thanks.tscn")


#youwin
func youwin() -> void:
	if _player == null:
		return
	#_show_result(true)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://ui/thanks.tscn")
	
	
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
	#道具只有一帧以上才需要逐帧播；生命格动画共用 _process，所以这里只开不关
	if _anim_frames != null and _anim_frames.get_frame_count(item_anim) > 1:
		set_process(true)

#按SpriteFrames的fps和每帧时长给图标换帧；生命格动画也在这里推进
func _process(delta: float) -> void:
	var busy: bool = _step_item_icon(delta)
	#if _step_hearts(delta):
		#busy = true
	set_process(busy)

#道具图标：返回是否还在播
func _step_item_icon(delta: float) -> bool:
	if _anim_frames == null:
		return false
	var fps: float = _anim_frames.get_animation_speed(item_anim)
	var count: int = _anim_frames.get_frame_count(item_anim)
	if fps <= 0.0 or count <= 1:
		return false
	var keep := true
	_anim_time += delta
	var dur: float = _anim_frames.get_frame_duration(item_anim, _anim_index) / fps
	while _anim_time >= dur:
		_anim_time -= dur
		if _anim_index + 1 >= count:
			if not _anim_frames.get_animation_loop(item_anim):
				keep = false
				break
			_anim_index = 0
		else:
			_anim_index += 1
		dur = _anim_frames.get_frame_duration(item_anim, _anim_index) / fps
	item_icon.texture = _anim_frames.get_frame_texture(item_anim, _anim_index)
	return keep

#准备每一格：挂 AtlasTexture；给了精灵图就按格子尺寸算列数/行数
func _collect_hearts() -> void:
	for h in $Lives.get_children():
		if h is AnimatedSprite2D:
			lives_row.append(h)
	#if heart_sheet:
		#_heart_cols = maxi(1, heart_sheet.get_width() / maxi(1, heart_frame_size.x))
		#_heart_rows = maxi(1, heart_sheet.get_height() / maxi(1, heart_frame_size.y))
	#else:
		##没图就当作只有一帧
		#_heart_cols = 1
		#_heart_rows = 1
	#var tex: Texture2D = heart_sheet if heart_sheet else heart_tex
	#_heart_atlas.clear()
	#_heart_row.clear()
	#_heart_col.clear()
	#_heart_time.clear()
	#for heart in lives_row.get_children():
		#if not (heart is TextureRect):
			#continue
		#var slot := heart as TextureRect
		#var atlas := AtlasTexture.new()
		#atlas.atlas = tex
		#atlas.region = Rect2(Vector2.ZERO, Vector2(heart_frame_size))
		#slot.texture = atlas
		#_heart_atlas.append(atlas)
		#_heart_row.append(-1)
		#_heart_col.append(0)
		#_heart_time.append(0.0)

#把第 i 格摆到某一帧（静止，不播）
#func _set_heart(i: int, row: int, col: int) -> void:
	#_set_heart_region(i, row, col)
	#_heart_row[i] = -1
	#_heart_col[i] = col

#func _set_heart_region(i: int, row: int, col: int) -> void:
	#_heart_atlas[i].region = Rect2(Vector2(col * heart_frame_size.x, row * heart_frame_size.y), Vector2(heart_frame_size))

#从某排第 0 帧开始播（0=扣血排，1=回血排）
#func _play_heart(i: int, row: int) -> void:
	#_heart_col[i] = 0
	#_heart_time[i] = 0.0
	#_heart_row[i] = row
	#_set_heart_region(i, row, 0)

#推进生命格动画，返回是否还有格子在播
#func _step_hearts(delta: float) -> bool:
	#var busy := false
	#for i in _heart_row.size():
		#if _heart_row[i] < 0:
			#continue
		#_heart_time[i] += delta
		#var dur: float = 1.0 / maxf(1.0, heart_fps)
		#while _heart_time[i] >= dur:
			#_heart_time[i] -= dur
			#if _heart_col[i] + 1 >= _heart_cols:
				#_heart_row[i] = -1
				#break
			#_heart_col[i] += 1
			#_set_heart_region(i, _heart_row[i], _heart_col[i])
		#if _heart_row[i] >= 0:
			#busy = true
	#return busy
#火把使用数显示
func match_used_count(matches_used):
	matchuse.text = "%d" % matches_used
