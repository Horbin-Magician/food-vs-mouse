class_name BoardController
extends RefCounted

signal placed(unit: Dictionary)
signal moved(unit: Dictionary, from_row: int, from_col: int)

var state: RunState
var data: Catalog

func _init(s: RunState, c: Catalog) -> void:
	state = s
	data = c

func at(row: int, col: int) -> Dictionary:
	for unit: Dictionary in state.units:
		if unit.row == row and unit.col == col:
			return unit
	return {}

func max_hp(id: String) -> float:
	return data.foods[id].stats.hp * data.rules.star_hp[state.star(id) - 1]

func place(id: String, row: int, col: int, paused: bool) -> String:
	if state.phase != "battle" or paused: return "仅可在未暂停的战斗中放置"
	if not state.cards.has(id) or row < 0 or row >= 5 or col < 0 or col >= 8: return "请选择持有卡与有效格子"
	if not at(row, col).is_empty(): return "格子已占用"
	var definition: Dictionary = data.foods[id].stats
	if state.heat < definition.cost: return "热量不足"
	if state.cooldowns.get(id, 0.0) > 0: return "卡牌冷却中"
	if id == "pudding":
		var count: int = 0
		for unit: Dictionary in state.units:
			if unit.id == id: count += 1
		if count >= data.rules.pudding_cap: return "布丁最多同时存在 5 个"
	state.heat -= definition.cost
	state.cooldowns[id] = float(definition.cooldown)
	state.units.append({"uid": state.uid(), "id": id, "row": row, "col": col, "hp": max_hp(id), "timer": 0.0, "attacks": 0, "flour": 0.0, "flash": 0.0})
	placed.emit(state.units[-1])
	if id == "pudding": state.metrics.puddings += 1
	return ""

func move(row: int, col: int, target_row: int, target_col: int) -> String:
	if state.phase != "prepare": return "只可在准备阶段调位"
	if target_row < 0 or target_row >= 5 or target_col < 0 or target_col >= 8: return "目标超出阵地"
	var source: Dictionary = at(row, col)
	if source.is_empty(): return "原格子为空"
	if row == target_row and col == target_col: return ""
	var target: Dictionary = at(target_row, target_col)
	if not target.is_empty():
		target.row = row
		target.col = col
		moved.emit(target, target_row, target_col)
	source.row = target_row
	source.col = target_col
	moved.emit(source, row, col)
	return ""

func remove(row: int, col: int, paused: bool, confirmed: bool) -> String:
	if paused or state.phase not in ["prepare", "battle"]: return "当前不能移除"
	if state.phase == "battle" and not confirmed: return "需要确认铲除"
	var unit: Dictionary = at(row, col)
	if unit.is_empty(): return "格子为空"
	state.units.erase(unit)
	return ""

func heal(ratio: float) -> void:
	for unit: Dictionary in state.units:
		unit.hp = minf(max_hp(unit.id), unit.hp + max_hp(unit.id) * ratio)

func repair() -> String:
	if state.phase != "prepare" or state.repaired: return "本准备阶段已维修或当前不可维修"
	if state.coins < data.rules.repair_cost: return "金币不足"
	state.coins -= data.rules.repair_cost
	state.repaired = true
	heal(data.rules.repair)
	return ""
