extends Node
class_name HeldItemInventory

#枚举清单，none是空手
enum HeldItem { NONE, KEY, SCEPTER ,WENG ,PIECE ,PIECES}
#物品状态新->旧
signal held_changed(old_kind: HeldItem, new_kind: HeldItem)
#物品离手
signal item_dropped(kind: HeldItem, count: int)
#拿起物品
signal item_taken(kind: HeldItem)
#拿起权杖应用无敌
signal invincible_apply
#放下权杖退出无敌
signal invincible_exit
var wait_leave := false
#空手
var held: HeldItem = HeldItem.NONE

#一个是piece，两个变成pieces
const PIECE_AMOUNTS := {
	HeldItem.PIECE: 1,
	HeldItem.PIECES: 2,
}




func get_held() -> HeldItem:
	return held
#开门用，询问有没有钥匙
func has_key() -> bool:
	return held == HeldItem.KEY
#通关用，询问有没有weng
func has_weng() -> bool:
	return held == HeldItem.WENG
## 这个状态算几个碎片（给 HUD / 掉落用）
func piece_amount(kind: HeldItem = held) -> int:
	return PIECE_AMOUNTS.get(kind, 0)
	
## 是不是碎片类（1 个或 2 个）
func _is_piece(kind: HeldItem) -> bool:
	return PIECE_AMOUNTS.has(kind)
	
func try_pickup(kind: HeldItem) -> bool:
	if kind == HeldItem.NONE:
		return false
	#让piece可叠加
	if _is_piece(held) and _is_piece(kind):
		var old := held
		if held == HeldItem.PIECE and kind == HeldItem.PIECE:
			held = HeldItem.PIECES           # 1 个 + 1 个 → 2 个
		elif held == HeldItem.PIECES and kind == HeldItem.PIECE:
			held = HeldItem.WENG             # 2 个 + 1 个 → 合成
		else:
			return false                     # 已经 2 个还想吃 2 个的、或倒着来 → 拒绝
		held_changed.emit(old, held)
		if held == HeldItem.WENG:
			item_taken.emit(held)
		return true
		
	if held == kind:
		return false        
	#传old还有count值给玩家按数量掉落物品（专为piece设置的数量参数）
	var old := held
	var old_amount := piece_amount(old)
	held = kind
	held_changed.emit(old, kind)

	if kind == HeldItem.SCEPTER:
		invincible_apply.emit()

	if old != HeldItem.NONE:
		item_dropped.emit(old, maxi(old_amount, 1))     # 非碎片类算 1 个
		if old == HeldItem.SCEPTER:
			invincible_exit.emit()
	item_taken.emit(kind)
	return true
#跨层时储存数据
func restore(kind: HeldItem) -> void:
	var old := held
	held = kind
	if old != held:
		held_changed.emit(old, held)
	if held == HeldItem.SCEPTER:
		invincible_apply.emit()
	elif old == HeldItem.SCEPTER:
		invincible_exit.emit()
