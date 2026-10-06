extends Node

@export var contents: Node2D
@export var items: Node2D

## 门/楼梯/胜利门进 FloorContents；钥匙等道具进 Items（含丢弃物）。
const SCENERY_SCENES := {
	HouseData.DOOR: true,
	HouseData.STAIR_UP: true,
	HouseData.STAIR_DOWN: true,
	HouseData.VICTORYDOOR: true,
}

var _spawned: Dictionary = {}
var _taken: Dictionary = {}
var _opened: Dictionary = {}
var _drops: Dictionary = {}
var _drop_serial := 0

func _ready() -> void:
	add_to_group("floor_loader")
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	assert(player != null, "关卡里找不到 player 组节点")
	assert(contents != null, "FloorLoader.contents 未绑定")
	assert(items != null, "FloorLoader.items 未绑定")
	player.floor_changed.connect(_load_floor, CONNECT_DEFERRED)
	_load_floor(player.current_floor)

func mark_taken(spawn_id: String) -> void:
	_taken[spawn_id] = true

func register_drop(packed: PackedScene, pos: Vector2, floor_num: int) -> Node2D:
	_drop_serial += 1
	var id := "drop_%d" % _drop_serial
	if not _drops.has(floor_num):
		_drops[floor_num] = []
	_drops[floor_num].append({"id": id, "scene": packed, "pos": pos})
	return _spawn_item(id, packed, pos, true)

func _parent_for(packed: PackedScene) -> Node2D:
	if SCENERY_SCENES.has(packed.resource_path):
		return contents
	return items

func _spawn_item(id: String, packed: PackedScene, pos: Vector2, set_wait_leave: bool, open: bool = false) -> Node2D:
	var node: Node2D = packed.instantiate()
	node.set_meta("spawn_id", id)
	if open:
		node.set("is_open", true)
	if set_wait_leave and "wait_leave" in node:
		node.wait_leave = true
	_parent_for(packed).add_child(node)
	node.global_position = pos
	_spawned[id] = node
	return node

func _load_floor(floor_num: int) -> void:
	_remember_doors()
	for child in contents.get_children():
		child.queue_free()
	for child in items.get_children():
		child.queue_free()
	_spawned.clear()
	for entry in HouseData.get_entries(floor_num):
		if _taken.has(entry.id):
			continue
		var packed: PackedScene = load(entry.scene)
		_spawn_item(entry.id, packed, entry.pos, false, _opened.has(entry.id))
	for entry in _drops.get(floor_num, []):
		if _taken.has(entry.id):
			continue
		_spawn_item(entry.id, entry.scene, entry.pos, false)

func _remember_doors() -> void:
	for id in _spawned:
		var node = _spawned[id]
		if is_instance_valid(node) and "is_open" in node and node.is_open:
			_opened[id] = true

func is_door_open(floor_num: int, door_position: Vector2) -> bool:
	_remember_doors()
	for entry in HouseData.get_entries(floor_num):
		if entry.scene == HouseData.DOOR and entry.pos == door_position:
			return _opened.has(entry.id)
	return true
