class_name MapTravel
extends RefCounted
#不要挂载到任何节点上
static var spawn_id: String = ""
static var has_run_data: bool = false
static var held: int = 0
static var lives: int = 2
static var matches_used: int = 0

static func clear() -> void:
	spawn_id = ""
	has_run_data = false
	held = 0
	lives = 2
	matches_used = 0

static func save_from(player: Node) -> void:
	var inv = player.get_node("Inventory")
	var match_light = player.get_node_or_null("MatchLight")
	held = inv.get_held()
	lives = player.lives
	matches_used = match_light.matches_used if match_light else 0
	has_run_data = true

static func apply_to(player: Node) -> void:
	if not has_run_data:
		return
	var inv = player.get_node("Inventory")
	var match_light = player.get_node_or_null("MatchLight")
	inv.restore(held)
	player.lives = lives
	player.lives_changed.emit(lives)
	if match_light:
		match_light.matches_used = matches_used
