extends Node2D
#用CanvasModulate做环境暗
#Scenery/Items的父节点modulate必须保持白色，否则火把光会被乘暗

@onready var world_dark: CanvasModulate = $WorldDark
@onready var scenery: Node2D = $Scenery
@onready var items: Node2D = $Items
@onready var player: Node2D = $Player
@onready var monsters: Node2D = $Monsters
@onready var hud: CanvasLayer = $CanvasLayer

const DARK := Color(0.04, 0.04, 0.04, 1)
const LIT := Color.WHITE

func _ready() -> void:
	if scenery:
		scenery.modulate = LIT
	if items:
		items.modulate = LIT
	
	_ignore_point_lights(player)
	_ignore_point_lights(monsters)
	_set_ambient_dark(true)


func _set_ambient_dark(on: bool) -> void:
	if world_dark:
		world_dark.color = DARK if on else LIT
	# 人怪与HUD用反向modulate抵消CanvasModulate，保持本色
	var cancel := Color(1.0 / DARK.r, 1.0 / DARK.g, 1.0 / DARK.b, 1.0) if on else LIT
	if player:
		player.modulate = cancel
	if monsters:
		monsters.modulate = cancel
	if hud:
		for child in hud.get_children():
			if child is CanvasItem:
				child.modulate = cancel
				child.light_mask = 0


func _ignore_point_lights(root: Node) -> void:
	if root == null:
		return
	# 人怪不受火把影响
	for n in root.find_children("*", "CanvasItem", true, false):
		(n as CanvasItem).light_mask = 0
