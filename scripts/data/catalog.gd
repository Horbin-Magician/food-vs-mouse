class_name Catalog
extends RefCounted

var foods: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Dictionary = {}
var waves: Array[Resource] = []
var rules: Dictionary = preload("res://resources/rules.tres").stats

func _init() -> void:
	for folder: String in ["foods", "enemies", "recipes", "waves"]:
		var files: PackedStringArray = ResourceLoader.list_directory("res://resources/" + folder)
		files.sort()
		for file: String in files:
			if not file.ends_with(".tres"):
				continue
			var definition: Resource = load("res://resources/" + folder + "/" + file)
			assert(not definition.id.is_empty())
			match folder:
				"foods":
					assert(not foods.has(definition.id),"duplicate food ID")
					foods[definition.id] = definition
				"enemies":
					assert(not enemies.has(definition.id),"duplicate enemy ID")
					enemies[definition.id] = definition
				"recipes":
					assert(not recipes.has(definition.id),"duplicate recipe ID")
					recipes[definition.id] = definition
				"waves": waves.append(definition)

	assert(validate().is_empty(),str(validate()))

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: String in foods:
		var stats: Dictionary = foods[id].stats
		for key: String in ["cost","cooldown","hp","damage","interval","reach","price"]:
			if not stats.has(key) or not stats[key] is float and not stats[key] is int or stats.get(key,-1) < 0: errors.append(id + ": " + key)
		if stats.get("hp",0) <= 0 or stats.get("cost",0) <= 0: errors.append(id + ": positive hp/cost required")
	for id: String in enemies:
		for key: String in ["hp","speed","dps","leak"]:
			if enemies[id].stats.get(key,0) <= 0: errors.append(id + ": " + key)
	for id: String in recipes:
		var required: String = recipes[id].stats.get("requires","")
		if required not in ["","area"] and not foods.has(required): errors.append(id + ": missing food")
	for wave: Resource in waves:
		if wave.stats.get("composition",[]).is_empty() or wave.stats.get("duration",0) < 5: errors.append(wave.id + ": empty wave")
		for id: String in wave.stats.get("composition",[]):
			if not enemies.has(id): errors.append(wave.id + ": missing enemy " + id)
		if wave.stats.has("batches"):
			var rows: Array = wave.stats.get("rows", [])
			var unique: Dictionary = {}
			for row: Variant in rows:
				if not row is int or row < 0 or row >= RunState.ROWS: errors.append(wave.id + ": invalid row")
				unique[row] = true
			if unique.size() < 3 or unique.size() != rows.size(): errors.append(wave.id + ": three distinct rows required")
			var count: int = 0
			var last_time: float = -1.0
			for batch: Dictionary in wave.stats.batches:
				var lanes: Array = batch.get("lanes", [])
				var start: float = batch.get("time", -1.0)
				var gap: float = batch.get("gap", 0.0)
				if lanes.is_empty() or not is_finite(start) or not is_finite(gap) or start < 5 or start <= last_time or gap <= 0:
					errors.append(wave.id + ": invalid batch timing")
				if not lanes.is_empty() and lanes[0] != 0: errors.append(wave.id + ": batch must start at lane zero")
				for i: int in range(lanes.size()):
					if not lanes[i] is int or lanes[i] < 0 or lanes[i] > 2: errors.append(wave.id + ": invalid lane slot")
					if i >= 2 and lanes[i] == lanes[i-1] and lanes[i] == lanes[i-2]: errors.append(wave.id + ": lane streak")
				if count == 0 and (lanes.size() < 3 or lanes[0] == lanes[1] or lanes[1] == lanes[2] or lanes[0] == lanes[2]):
					errors.append(wave.id + ": first three lanes must differ")
				count += lanes.size()
				last_time = start + (lanes.size() - 1) * gap
			if count != wave.stats.composition.size(): errors.append(wave.id + ": batch count mismatch")
	return errors
