class_name Catalog
extends RefCounted

var foods: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Dictionary = {}
var waves: Array[Resource] = []
var rules: Dictionary = {"heat_start": 150.0, "heat_cap": 350.0, "heat_rate": 5.0, "pudding_cap": 5, "production": 15.0, "heal": 0.15, "repair": 0.30, "repair_cost": 4, "refresh_cost": 2, "refresh_limit": 2, "star_hp": [1.0, 1.35, 1.75], "star_production": [1.0, 1.2, 1.4], "rewards": [6,7,8,10,9,10,12], "bonus": 2, "projectile_speed": 420.0}

func _init() -> void:
	for folder: String in ["foods", "enemies", "recipes", "waves"]:
		var files: PackedStringArray = DirAccess.get_files_at("res://resources/" + folder)
		files.sort()
		for file: String in files:
			if not file.ends_with(".tres"):
				continue
			var definition: Resource = load("res://resources/" + folder + "/" + file)
			assert(not definition.id.is_empty())
			match folder:
				"foods": foods[definition.id] = definition
				"enemies": enemies[definition.id] = definition
				"recipes": recipes[definition.id] = definition
				"waves": waves.append(definition)
