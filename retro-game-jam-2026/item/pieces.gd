extends Area2D
#再捡一个piece就合成weng
@export var item_kind: HeldItemInventory.HeldItem = HeldItemInventory.HeldItem.PIECES

var wait_leave := false

func _ready() -> void:
	monitoring = true
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)



func _on_body_entered(body: Node2D) -> void:
	if wait_leave:
		return
	#捡起成功后先告诉 floor_loader（换层回来不再生成），再销毁
	if body.is_in_group("player") and body.has_method("try_pickup_at") and body.try_pickup_at(item_kind, global_position):
		if has_meta("spawn_id"):
			var loader = get_tree().get_first_node_in_group("floor_loader")
			if loader:
				loader.mark_taken(get_meta("spawn_id"))
		queue_free()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		wait_leave = false
