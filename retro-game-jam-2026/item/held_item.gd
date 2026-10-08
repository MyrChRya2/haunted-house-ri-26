extends Node
class_name HeldItemInventory

#枚举清单，none是空手
enum HeldItem { NONE, KEY, SCEPTER, WENG, PIECEM, PIECES, PIECEL, PIECER }
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
#两片合成 pieces、三片合成 weng
signal pieces_crafted
signal weng_crafted
var wait_leave := false
#空手
var held: HeldItem = HeldItem.NONE


func get_held() -> HeldItem:
	return held
#开门用，询问有没有钥匙
func has_key() -> bool:
	return held == HeldItem.KEY
#通关用，询问有没有weng
func has_weng() -> bool:
	return held == HeldItem.WENG

#是不是碎片类
func _is_piece(kind: HeldItem) -> bool:
	return _is_single_piece(kind) or kind == HeldItem.PIECES

func _is_single_piece(kind: HeldItem) -> bool:
	return kind == HeldItem.PIECEM or kind == HeldItem.PIECEL or kind == HeldItem.PIECER

func try_pickup(kind: HeldItem) -> bool:
	if kind == HeldItem.NONE:
		return false
	#piece可叠加
	if _is_piece(kind):
		if held == HeldItem.NONE:
			held = kind
			held_changed.emit(HeldItem.NONE, held)
			item_taken.emit(held)
			return true
		if _is_single_piece(held) and _is_single_piece(kind):
			if held == kind:
				return false
			var old_pair := held
			held = HeldItem.PIECES
			held_changed.emit(old_pair, held)
			pieces_crafted.emit()
			return true
		if (held == HeldItem.PIECES and _is_single_piece(kind)) or (_is_single_piece(held) and kind == HeldItem.PIECES):
			var old_tri := held
			held = HeldItem.WENG
			held_changed.emit(old_tri, held)
			item_taken.emit(held)
			weng_crafted.emit()
			return true
		if held == HeldItem.WENG:
			return false

	if held == kind:
		return false
	#换手
	var old := held
	held = kind
	held_changed.emit(old, kind)

	if kind == HeldItem.SCEPTER:
		invincible_apply.emit()

	if old != HeldItem.NONE:
		item_dropped.emit(old, 1)
		if old == HeldItem.SCEPTER:
			invincible_exit.emit()
	item_taken.emit(kind)
	return true
