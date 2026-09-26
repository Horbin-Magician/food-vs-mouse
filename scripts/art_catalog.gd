class_name ArtCatalog
extends RefCounted

const BACKGROUND: Texture2D = preload("res://assets/art/kitchen.png")
const FOOD_SHEET: Texture2D = preload("res://assets/art/foods.png")
const BUN_SHEET: Texture2D = preload("res://assets/art/food_frames/bun.png")
const MOUSE_SHEET: Texture2D = preload("res://assets/art/mice.png")
const RECIPE_SHEET: Texture2D = preload("res://assets/art/recipes.png")
const FOOD_IDS: Array[String] = ["bun", "toast", "pudding", "tea", "pepper", "popcorn", "noodles", "garlic"]
const MOUSE_IDS: Array[String] = ["gray", "runner", "lid", "gnawer", "drummer", "flour", "elite", "boss"]
const CHAPTER_MOUSE_IDS: Array[String] = [
	"spoon_skater", "towel_scout", "rivet_guard", "tong_breaker",
	"vinegar_spitter", "dough_rat", "ration_keeper", "skewer_lancer",
	"spoon_captain", "rivet_foreman", "vinegar_cellarer", "skewer_marshal",
	"boss_windwhistle", "boss_ironpot", "boss_starter", "boss_quartermaster",
]
const UNARMORED_IDS: Array[String] = ["rivet_guard", "rivet_foreman", "boss_ironpot"]
const RECIPE_IDS: Array[String] = ["pressure", "wide", "recycle", "burst", "ice", "cold_spice", "burn", "long", "caramel", "breakfast", "reheat", "crust"]
var foods: Dictionary = {}
var food_portraits: Dictionary = {}
var mice: Dictionary = {}
var mouse_frames: Dictionary = {}
var enemy_skill_frames: Dictionary = {}
var unarmored_skill_frames: Dictionary = {}
var unarmored_frames: Dictionary = {}
var bun_frames: Array[Texture2D] = []
var recipes: Dictionary = {}

func _init() -> void:
	for row: int in range(6):
		for col: int in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = BUN_SHEET
			frame.region = Rect2(Vector2(col, row) * 256, Vector2(256, 256))
			frame.filter_clip = true
			bun_frames.append(frame)
	fill(foods, FOOD_SHEET, FOOD_IDS, 2)
	var food_image: Image = FOOD_SHEET.get_image()
	for id: String in FOOD_IDS:
		var source: AtlasTexture = foods[id]
		var region := Rect2i(source.region)
		var bounds: Rect2i = food_image.get_region(region).get_used_rect()
		var portrait := AtlasTexture.new()
		portrait.atlas = FOOD_SHEET
		portrait.region = Rect2(bounds.grow(8).intersection(Rect2i(Vector2i.ZERO, region.size)))
		portrait.region.position += source.region.position
		portrait.filter_clip = true
		food_portraits[id] = portrait
	fill(mice, MOUSE_SHEET, MOUSE_IDS, 2)
	for id: String in MOUSE_IDS:
		var sheet: Texture2D = load("res://assets/art/mouse_frames/%s.png" % id)
		var frames: Array[Texture2D] = []
		var cell: Vector2 = sheet.get_size() / Vector2(6, 4)
		for row: int in range(4):
			for col: int in range(6):
				var frame := AtlasTexture.new()
				frame.atlas = sheet
				frame.region = Rect2(Vector2(col, row) * cell, cell)
				frame.filter_clip = true
				frames.append(frame)
		mouse_frames[id] = frames
	for id: String in CHAPTER_MOUSE_IDS:
		var sheet_path := "res://assets/art/mouse_frames/%s.png" % id
		if not ResourceLoader.exists(sheet_path):
			continue
		var frames := load_mouse_frames(sheet_path, 4)
		mouse_frames[id] = frames
		mice[id] = frames[0]
		var skill_path := "res://assets/art/enemy_skills/%s.png" % id
		if ResourceLoader.exists(skill_path):
			enemy_skill_frames[id] = load_mouse_frames(skill_path, 3)
		if id in UNARMORED_IDS:
			var unarmored_path := "res://assets/art/mouse_frames/%s_unarmored.png" % id
			if ResourceLoader.exists(unarmored_path):
				unarmored_frames[id] = load_mouse_frames(unarmored_path, 4)
			var unarmored_skill_path := "res://assets/art/enemy_skills/%s_unarmored.png" % id
			if ResourceLoader.exists(unarmored_skill_path):
				unarmored_skill_frames[id] = load_mouse_frames(unarmored_skill_path, 3)
	fill(recipes, RECIPE_SHEET, RECIPE_IDS, 3)

func load_mouse_frames(path: String, rows: int) -> Array[Texture2D]:
	var sheet: Texture2D = load(path)
	var frames: Array[Texture2D] = []
	var cell := sheet.get_size() / Vector2(6, rows)
	for row: int in range(rows):
		for col: int in range(6):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(col, row) * cell, cell)
			frame.filter_clip = true
			frames.append(frame)
	return frames

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

func bun_frame(frame: Vector2i) -> Texture2D:
	return bun_frames[frame.y * 6 + frame.x]

func mouse(id: String) -> Texture2D:
	return mice.get(id)

func recipe(id: String) -> Texture2D:
	return recipes.get(id)

func food_portrait(id: String) -> Texture2D:
	return food_portraits.get(id)

func mouse_frame(id: String, frame: Vector2i) -> Texture2D:
	return mouse_frames[id][frame.y * 6 + frame.x]

func mouse_frame_for_state(id: String, frame: Vector2i, unarmored: bool = false) -> Texture2D:
	if unarmored and unarmored_frames.has(id):
		return unarmored_frames[id][frame.y * 6 + frame.x]
	return mouse_frame(id, frame)

func skill_frame(id: String, frame: Vector2i, unarmored: bool = false) -> Texture2D:
	if unarmored and unarmored_skill_frames.has(id):
		return unarmored_skill_frames[id][clampi(frame.y, 0, 2) * 6 + clampi(frame.x, 0, 5)]
	if unarmored: return null
	if not enemy_skill_frames.has(id):
		return null
	return enemy_skill_frames[id][clampi(frame.y, 0, 2) * 6 + clampi(frame.x, 0, 5)]
