extends Area2D
#两个合成pieces，三个合成weng
#右
@export var item_kind: HeldItemInventory.HeldItem = HeldItemInventory.HeldItem.PIECER

var wait_leave := false

func _ready() -> void:
	monitoring = true
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)



func _on_body_entered(body: Node2D) -> void:
	if wait_leave:
		return
	if body.is_in_group("player") and body.has_method("try_pickup_at") and body.try_pickup_at(item_kind, global_position):
		queue_free()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		wait_leave = false
