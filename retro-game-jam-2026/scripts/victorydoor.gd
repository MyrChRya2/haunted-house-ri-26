extends StaticBody2D
#判定游戏胜利的门，基本抄门的代码
class_name victorydoor

@onready var _detect: Area2D = $Area2D


#信号发给玩家冻结操作，发给label显示youwin
signal win

var is_win :bool = false

func _ready() -> void:
	_detect.monitoring = true
	_detect.body_entered.connect(_on_detect_body_entered)
	#胜利门主动连接玩家，冻结行动
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("win"):
		win.connect(player.win)   
	#主动连接怪物，冻结行动
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_method("_freeze") and not win.is_connected(m._freeze):
			win.connect(m._freeze)
	
func _on_detect_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	#门生成后主动连接label，防止初始化早于楼层数据加载无法连接信号导致崩溃
	var hub := get_tree().get_first_node_in_group("hub")
	if hub != null and hub.has_method("youwin"):
		win.connect(hub.youwin)
	try_win(body)

func try_win(player: Node) -> bool:
	if player == null or not player.has_method("has_weng"):
		return false
	if not player.has_weng():
		return false
	#发送信号给玩家冻结操作
	win.emit()
	return true
	
