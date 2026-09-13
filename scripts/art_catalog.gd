class_name ArtCatalog
extends RefCounted

const BACKGROUND: Texture2D = preload("res://assets/art/kitchen.png")
const FOOD_SHEET: Texture2D = preload("res://assets/art/foods.png")
const MOUSE_SHEET: Texture2D = preload("res://assets/art/mice.png")
const RECIPE_SHEET: Texture2D = preload("res://assets/art/recipes.png")
const FOOD_IDS: Array[String] = ["bun", "toast", "pudding", "tea", "pepper", "popcorn", "noodles", "garlic"]
const MOUSE_IDS: Array[String] = ["gray", "runner", "lid", "gnawer", "drummer", "flour", "elite", "boss"]
const RECIPE_IDS: Array[String] = ["pressure", "wide", "recycle", "burst", "ice", "cold_spice", "burn", "long", "caramel", "breakfast", "reheat", "crust"]
var foods: Dictionary = {}
var mice: Dictionary = {}
var recipes: Dictionary = {}

func _init() -> void:
	fill(foods, FOOD_SHEET, FOOD_IDS, 2)
	fill(mice, MOUSE_SHEET, MOUSE_IDS, 2)
	fill(recipes, RECIPE_SHEET, RECIPE_IDS, 3)

func fill(target: Dictionary, sheet: Texture2D, ids: Array[String], rows: int) -> void:
	var cell: Vector2 = sheet.get_size() / Vector2(4, rows)
	for index: int in range(ids.size()):
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
		texture.filter_clip = true
		target[ids[index]] = texture

func food(id: String) -> Texture2D:
	return foods.get(id)

func mouse(id: String) -> Texture2D:
	return mice.get(id)

func recipe(id: String) -> Texture2D:
	return recipes.get(id)
