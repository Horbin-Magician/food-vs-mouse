class_name RecipeSystem
extends RefCounted

var state: RunState
var data: Catalog
# Optional food id -> occupied cells snapshot; only valid while the caller keeps units fixed.
var occupancy: Dictionary = {}
var indexed: bool = false

func _init(s: RunState, c: Catalog) -> void:
	state = s
	data = c

func has(id: String) -> bool:
	return id in state.recipes

func value(id: String, key: String, fallback: float = 0.0) -> float:
	return data.recipes[id].stats.get(key,fallback) if has(id) else fallback

func eligible(id: String, unlocked: Array) -> bool:
	var stats: Dictionary = data.recipes[id].stats
	if has(id) or (stats.has("unlock") and id not in unlocked): return false
	var required: String = stats.requires
	if required == "area": return state.cards.has("popcorn") or has("pressure")
	return required.is_empty() or state.cards.has(required)

func offer(rng: RandomNumberGenerator, unlocked: Array) -> void:
	state.choices.clear()
	var pool: Array = []
	for id: String in data.recipes:
		if eligible(id,unlocked): pool.append(id)
	while not pool.is_empty() and state.choices.size() < 3:
		state.choices.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))

# Callers must not add, remove or move units between index_units() and clear_index().
func index_units() -> void:
	occupancy.clear()
	for unit: Dictionary in state.units:
		if not occupancy.has(unit.id): occupancy[unit.id] = {}
		occupancy[unit.id][Vector2i(unit.col, unit.row)] = true
	indexed = true

func clear_index() -> void:
	occupancy.clear()
	indexed = false

func adjacent(unit: Dictionary, id: String) -> bool:
	if indexed:
		var cells: Dictionary = occupancy.get(id, {})
		if cells.is_empty(): return false
		var cell := Vector2i(unit.col, unit.row)
		return cells.has(cell + Vector2i.LEFT) or cells.has(cell + Vector2i.RIGHT) or cells.has(cell + Vector2i.UP) or cells.has(cell + Vector2i.DOWN)
	for other: Dictionary in state.units:
		if other.id == id and absi(other.row-unit.row) + absi(other.col-unit.col) == 1: return true
	return false

func interval(unit: Dictionary) -> float:
	var stats: Dictionary = data.foods[unit.id].stats
	if stats.kind == "producer": return stats.interval
	var bonus: float = 0.0
	if adjacent(unit,"garlic"): bonus += data.foods.garlic.stats.aura
	var penalty: float = float(data.rules.flour_penalty) if unit.flour > 0 else 0.0
	if float(unit.get("proof_time", 0.0)) > 0: penalty = maxf(penalty, float(unit.get("proof_penalty", 0.0)))
	bonus -= penalty
	return maxf(data.rules.min_interval,stats.interval / (1.0 + bonus))

func damage(unit: Dictionary) -> float:
	var result: float = data.foods[unit.id].stats.damage * state.stat_multiplier(unit.id, data)
	if has("breakfast") and adjacent(unit,"pudding"): result *= value("breakfast","multiplier")
	return result

func reach(id: String) -> float:
	return value("long","reach",data.foods[id].stats.reach) if id == "pepper" else data.foods[id].stats.reach

func radius(unit: Dictionary) -> float:
	var result: float = data.foods[unit.id].stats.get("radius",0.0)
	if unit.id == "bun" and has("pressure") and unit.attacks % int(value("pressure","every")) == 0:
		result = value("pressure","radius")
	return result * value("wide","multiplier",1.0)
