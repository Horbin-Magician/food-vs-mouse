class_name RunState
extends RefCounted

const ROWS: int = 7
const COLS: int = 9
const CELL_WIDTH: int = 96
const BOARD_WIDTH: int = COLS * CELL_WIDTH
const CENTER_ROW: int = ROWS / 2

var run_id: String = ""
var seed_value: int = 1
var scene_id: String = "kitchen"
var chapter_id: String = "kitchen_1"
var wave: int = 1
var start_wave: int = 1
var _catalog: Catalog
var difficulty: String = "easy"
var phase: String = "prepare"
var pantry: int = 10
var heat: float = 150.0
var cards: Dictionary = {"bun": 1, "toast": 1, "pudding": 1}
var loadout: Array = []
var levels: Dictionary = {}
var legacy_stars: bool = false
var inspiration_earned: Dictionary = {}
var inspiration_collected: Dictionary = {}
var reward_floor: int = 0
var rewards_enabled: bool = true
var recipes: Array = []
var units: Array = []
var cooldowns: Dictionary = {}
var offers: Array = []
var choices: Array = []
var refreshes: int = 0
var repaired: bool = false # Legacy version-1 save field; no gameplay effect.
var leaks: int = 0
var elapsed: float = 0.0
var next_uid: int = 1
var metrics: Dictionary = {"kills": 0, "puddings": 0, "passed": 0, "leaks": 0, "deaths": 0, "overflow": 0.0, "damage": {}, "recipes": []}

func _init(catalog: Catalog = null) -> void:
	_catalog = catalog

func global_wave() -> int:
	if _catalog == null: _catalog = Catalog.new()
	return _catalog.chapter_offset(scene_id, chapter_id) + wave

func star(id: String) -> int:
	if not legacy_stars: return 1
	var count: int = cards.get(id, 0)
	return 3 if count >= 6 else (2 if count >= 3 else 1)

func uid() -> int:
	var result: int = next_uid
	next_uid += 1
	return result

func level(id: String) -> int:
	return int(levels.get(id, 0))

func stat_multiplier(id: String, data: Catalog) -> float:
	return data.rules.star_hp[star(id) - 1] if legacy_stars else 1.0 + level(id) * data.progression.stat_per_level

func production_multiplier(id: String, data: Catalog) -> float:
	return data.rules.star_production[star(id) - 1] if legacy_stars else 1.0 + level(id) * data.progression.production_per_level

func inspiration_for_wave(index: int, data: Catalog) -> int:
	if not rewards_enabled: return 0
	return int(inspiration_earned.get(str(index + 1), data.progression.inspiration_rewards[index % data.progression.inspiration_rewards.size()]))

func collected_inspiration() -> int:
	var total: int = 0
	for amount: Variant in inspiration_collected.values(): total += int(amount)
	return total
