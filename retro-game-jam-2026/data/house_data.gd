
class_name HouseData
extends RefCounted
#以文件系统面板大小写为准
#道具
const STAIR_UP := "res://scenes/Stairup.tscn"
const STAIR_DOWN := "res://scenes/Stairdown.tscn"
const DOOR := "res://scenes/door.tscn"
const KEY := "res://item/Key.tscn"
const SCEPTER := "res://item/Scepter.tscn"
const VICTORYDOOR := "res://scenes/VictoryDoor.tscn"
const PIECE := "res://item/Piece.tscn"
const PIECES := "res://item/Pieces.tscn"
const WENG  := "res://item/Weng.tscn"
#房间坐标，前两位是房间左上角的点坐标，后两位是x和y轴的长度
const ROOMS := {
	"room_0": Rect2(0, 0, 80, 88),
	"room_1": Rect2(80, 0, 80, 88),
	"room_2": Rect2(0, 88, 80, 80),
	"room_3": Rect2(80, 88, 80, 80),
	"room_4": Rect2(0, 168, 80, 88),
	"room_5": Rect2(80, 168, 80, 88),
}
#怪物寻路用
const LINKS := [
	{"a": "room_0", "b": "room_1", "door_position": Vector2(80, 56)},
	{"a": "room_0", "b": "room_2", "door_position": Vector2(40, 88)},
	{"a": "room_1", "b": "room_3", "door_position": Vector2(120, 88)},
	{"a": "room_2", "b": "room_3", "door_position": Vector2(80, 136)},
	{"a": "room_2", "b": "room_4", "door_position": Vector2(40, 168)},
	{"a": "room_3", "b": "room_5", "door_position": Vector2(120, 168)},
	{"a": "room_4", "b": "room_5", "door_position": Vector2(80, 216)},
]

# 投放怪物
const PATROL_XS := [40.0, 120.0]
const PATROL_YS := [56.0, 136.0, 216.0]

static func random_patrol_point() -> Vector2:
	return Vector2(PATROL_XS.pick_random(), PATROL_YS.pick_random())

#每个楼层的道具信息
#上下楼的pos要相等
const FLOORS := {
	1: [
		{"id": "f1_up", "scene": STAIR_UP, "room_id": "room_0", "pos": Vector2(40, 10)},
		{"id": "f1_door", "scene": DOOR, "room_id": "room_0", "pos": Vector2(40, 88)},
		{"id": "f1_key", "scene": KEY, "room_id": "room_3", "pos": Vector2(120, 128)},
		{"id": "f1_victorydoor", "scene": VICTORYDOOR, "room_id": "room_3", "pos": Vector2(152, 120)},
		{"id": "f1_piece", "scene":PIECE, "room_id": "room_3", "pos": Vector2(32, 208)},
		{"id": "f1_piece", "scene":WENG, "room_id": "room_1", "pos": Vector2(112, 48)},
		{"id": "f1_piece", "scene":WENG, "room_id": "room_1", "pos": Vector2(118, 112)},
	],
	2: [
		{"id": "f2_down", "scene": STAIR_DOWN, "room_id": "room_0", "pos": Vector2(40, 10)},
		{"id": "f2_up", "scene": STAIR_UP, "room_id": "room_5", "pos": Vector2(120, 232)},
		{"id": "f2_scepter", "scene": SCEPTER, "room_id": "room_2", "pos": Vector2(40, 128)},
		{"id": "f2_piece", "scene":PIECE, "room_id": "room_1", "pos": Vector2(120, 32)},
	],
	3: [
		{"id": "f3_down", "scene": STAIR_DOWN, "room_id": "room_5", "pos": Vector2(120, 232)},
		{"id": "f3_up", "scene": STAIR_UP, "room_id": "room_1", "pos": Vector2(120, 16)},
		{"id": "f3_piece", "scene":PIECE, "room_id": "room_0", "pos": Vector2(56, 40)},
	],
	4: [
		{"id": "f4_down", "scene": STAIR_DOWN, "room_id": "room_1", "pos": Vector2(120, 16)},
	],
}

static func get_entries(floor_num: int) -> Array:
	return FLOORS.get(floor_num, [])

static func get_exits(room_id: String) -> Array:
	var result := []
	for link in LINKS:
		if link.a == room_id:
			result.append({"to": link.b, "door_position": link.door_position})
		elif link.b == room_id:
			result.append({"to": link.a, "door_position": link.door_position})
	return result

static func get_stairs(floor_num: int, room_id: String) -> Array:
	var result := []
	for e in get_entries(floor_num):
		if e.room_id != room_id:
			continue
		if e.scene == STAIR_UP:
			result.append({"pos": e.pos, "floor_delta": 1})
		elif e.scene == STAIR_DOWN:
			result.append({"pos": e.pos, "floor_delta": -1})
	return result

static func room_at(point: Vector2) -> String:
	for id in ROOMS:
		if ROOMS[id].has_point(point):
			return id
	return ""
