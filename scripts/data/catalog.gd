class_name Catalog
extends RefCounted

var foods: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Dictionary = {}
var waves: Array[Resource] = []
var rules: Dictionary = preload("res://resources/rules.tres").stats

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
