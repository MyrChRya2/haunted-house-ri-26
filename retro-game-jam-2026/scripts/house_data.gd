extends RefCounted
class_name HouseData
# 旧房间表已废弃。怪物新 AI 替换前保留空实现，避免 ghost/vampire/tarantula 解析报错。

const PATROL_XS: Array = [0.0]
const PATROL_YS: Array = [0.0]
const LINKS: Array = []

static func room_at(_pos: Vector2) -> String:
	return ""

static func random_patrol_point() -> Vector2:
	return Vector2.ZERO

static func get_stairs(_floor: int, _room: String) -> Array:
	return []
