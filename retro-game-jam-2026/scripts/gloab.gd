extends Node2D
# 环境暗改由 MatchLight/VisionMask 负责，不再用 WorldDark+PointLight 叠乘

@onready var world_dark: CanvasModulate = $WorldDark
@onready var scenery: Node2D = $Scenery
@onready var items: Node2D = $Items
@onready var player: Node2D = $Player
@onready var monsters: Node2D = $Monsters
@onready var hud: CanvasLayer = $CanvasLayer

const LIT := Color.WHITE

func _ready() -> void:
	if scenery:
		scenery.modulate = LIT
	if items:
		items.modulate = LIT
	if world_dark:
		world_dark.color = LIT
	if player:
		player.modulate = LIT
	if monsters:
		monsters.modulate = LIT
	if hud:
		for child in hud.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = LIT
				(child as CanvasItem).light_mask = 0
	_ignore_point_lights(player)
	_ignore_point_lights(monsters)


func _ignore_point_lights(root: Node) -> void:
	if root == null:
		return
	for n in root.find_children("*", "CanvasItem", true, false):
		(n as CanvasItem).light_mask = 0
