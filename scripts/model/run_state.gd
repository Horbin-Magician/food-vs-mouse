class_name RunState
extends RefCounted

const ROWS: int = 7
const COLS: int = 9
const CELL_WIDTH: int = 96
const BOARD_WIDTH: int = COLS * CELL_WIDTH
const CENTER_ROW: int = ROWS / 2

var run_id: String = ""
var seed_value: int = 1
var wave: int = 1
var phase: String = "prepare"
var coins: int = 6
var pantry: int = 10
var heat: float = 150.0
var cards: Dictionary = {"bun": 1, "toast": 1, "pudding": 1}
var recipes: Array = []
var units: Array = []
var cooldowns: Dictionary = {}
var offers: Array = []
var choices: Array = []
var refreshes: int = 0
var repaired: bool = false
var leaks: int = 0
var elapsed: float = 0.0
var next_uid: int = 1
var metrics: Dictionary = {"kills": 0, "puddings": 0, "passed": 0, "leaks": 0, "deaths": 0, "overflow": 0.0, "damage": {}, "recipes": []}

func star(id: String) -> int:
	var count: int = cards.get(id, 0)
	return 3 if count >= 6 else (2 if count >= 3 else 1)

func uid() -> int:
	var result: int = next_uid
	next_uid += 1
	return result
