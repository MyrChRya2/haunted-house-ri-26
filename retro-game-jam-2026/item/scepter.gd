extends Area2D
#拿在手上免疫伤害
@export var item_kind: HeldItemInventory.HeldItem = HeldItemInventory.HeldItem.SCEPTER

var wait_leave := false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if wait_leave:
		return
	if body.is_in_group("player") and body.has_method("try_pickup") and body.try_pickup(item_kind):
		if has_meta("spawn_id"):
			var loader = get_tree().get_first_node_in_group("floor_loader")
			if loader:
				loader.mark_taken(get_meta("spawn_id"))
		queue_free()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		wait_leave = false
