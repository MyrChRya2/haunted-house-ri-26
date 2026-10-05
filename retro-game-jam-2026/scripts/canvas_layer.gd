extends CanvasLayer
#hub脚本

#道具

#血量
@onready var lives_label: Label = $Lives
#楼层
@onready var floor: Label = $Floor
#gameover
@onready var _gameover: Label = $gameover
#显示youwin
@onready var _winthegame: Label = $winthegame
#发出信号的节点
@onready var victory: Node = get_tree().get_first_node_in_group("victory")
#道具图标显示节点
@onready var item_icon: TextureRect = $ItemIcon
#道具图片枚举
@export var item_icons: Array[Texture2D] = []
#火把计数器
@onready var matchuse: Label = $match

#玩家节点，在ready中通过get_tree获取
var _player: Node
#仓库节点（拾取道具系统）,通过玩家子节点获得
var _inv: Node = null
#火把节点,通过玩家子节点获得
var _match: Node

#获取player组里面的player节点，监听lives_changed信号，显示初始生命
func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		push_warning("player 组里没有节点：检查 Player 是否加入 player 组")
		return
	_player.lives_changed.connect(_on_lives_changed)
	lives_label.text = "Lives: %d" % _player.lives
	#监听floor_changed信号，显示初始楼层
	_player.floor_changed.connect(_on_floor_changed)
	floor.text = "Floor: %d" % _player.current_floor
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
#更新血量
func _on_lives_changed(current: int) -> void:
	if _player == null:
		return
	lives_label.text = "Lives: %d" % current
func _on_floor_changed(current_f: int) -> void:
	if _player == null:
		return
	floor.text = "Floor: %d" % current_f

#gameover
func over() -> void:
	if _player == null:
		return
	_gameover.text = "gameover"

#youwin
func youwin() -> void:
	if _player == null:
		return
	_winthegame.text = "youwin"

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
	var tex: Texture2D = null
	if kind >= 0 and kind < item_icons.size():
		tex = item_icons[kind]
	item_icon.texture = tex
	item_icon.visible = (tex != null)
#火把使用数显示
func match_used_count(matches_used):
	matchuse.text = "match: %d" % matches_used
