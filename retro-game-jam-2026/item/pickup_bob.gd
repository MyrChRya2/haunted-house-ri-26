extends Node2D
#可拾取物品的上下浮动/弹跳 —— 挂在物品的【视觉子节点】上（Sprite2D / AnimatedSprite2D 都能挂）
#
#为什么不挂在物品根节点（Area2D）上？因为 7 个物品脚本的拾取判定用的是根节点的位置：
#	body.try_pickup_at(item_kind, global_position)      # item/key.gd:19-21
#而 try_pickup_at() 内部第一步就是 is_lit_at(pos) 判"有没有被火把照到"——根节点一抖，这个判定位置
#就跟着抖（以后做存档、落地对齐也会踩）。所以：**对象不动，只让画面跳**。
#
#为什么用 extends Node2D？因为这 7 个物品的视觉子节点类型不统一：
#	Key / Pieces / Shild / Weng  → AnimatedSprite2D
#	piece_m / piece_l / piece_r  → Sprite2D（名字分别是 Piece / Piecel / Piecer）
#Node2D 是它们共同的父类，所以两边都挂得上，脚本里也不用写死 $AnimatedSprite2D。

@export var amplitude: float = 2.0   #振幅（像素）。本项目开了像素对齐，建议整数：2 → 画面只有 5 个离散高度
@export var period: float = 1.0      #一个来回几秒：0.8~1.2 像呼吸/悬浮，0.5~0.7 更像弹跳
@export var phase: float = 0.0       #相位 0~1：同屏多个物品填不同值（0 / 0.33 / 0.66），免得齐步跳

var _base_y: float = 0.0             #进场景时的高度，所有偏移都基于它
var _t: float = 0.0                  #已经跑了多久

func _ready() -> void:
	_base_y = position.y
	_t = phase * period              #把 0~1 的相位换算成"已经跑了多久"

func _process(delta: float) -> void:
	_t += delta
	#每次都拿 base + 偏移重算（不是 += 累加），避免浮点误差越积越大
	position.y = _base_y + sin(_t * TAU / period) * amplitude
	#想更像"弹跳"（跳起来、落回原处、再跳，落地有停顿感），把上面那行换成下面这行：
	#	position.y = _base_y - absf(sin(_t * TAU / period)) * amplitude
