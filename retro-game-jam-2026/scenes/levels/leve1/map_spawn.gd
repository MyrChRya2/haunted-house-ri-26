extends Node2D
#挂载到每一张地图的根节点上
func _ready() -> void:
	if MapTravel.spawn_id.is_empty():
		return
	var marker := find_child(MapTravel.spawn_id, true, false) as Marker2D
	var player := get_tree().get_first_node_in_group("player")
	MapTravel.spawn_id = ""
	if marker == null or player == null:
		push_warning("map_spawn: 找不到 Marker2D 或 player")
		return
	player.global_position = marker.global_position
