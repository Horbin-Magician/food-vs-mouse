class_name ShopController
extends RefCounted

signal card_upgraded(food_id: String, star: int)
var state: RunState
var data: Catalog
var board: BoardController
var recipes: RecipeSystem
var unlocked: Array = []
var rng: RandomNumberGenerator

func _init(s: RunState, c: Catalog, b: BoardController, random: RandomNumberGenerator, recipe_system: RecipeSystem, unlocked_ids: Array) -> void:
	state = s
	data = c
	board = b
	rng = random
	recipes = recipe_system
	unlocked = unlocked_ids

func is_open() -> bool:
	return state.phase == "prepare" and state.wave == 1 and state.global_wave() > state.start_wave

func close() -> void:
	state.offers.clear()
	state.choices.clear()
	state.refreshes = 0

func open() -> void:
	if not is_open(): return
	state.refreshes = 0
	generate()

func generate() -> void:
	if not is_open(): return
	state.offers.clear()
	recipes.offer(rng, unlocked)

func buy(_index: int) -> String:
	return "卡片请在局外卡店购买；本局只出售食谱"

func refresh() -> String:
	if not is_open(): return "仅大关通关后的小铺可刷新"
	if state.refreshes >= data.rules.refresh_limit: return "刷新次数已用完"
	if state.heat < data.rules.refresh_cost: return "热量不足"
	state.heat -= data.rules.refresh_cost
	state.refreshes += 1
	generate()
	return ""

func buy_recipe(id: String) -> String:
	if not is_open(): return "仅大关通关后的小铺可购买"
	if id not in state.choices or not data.recipes.has(id) or not recipes.eligible(id, unlocked): return "食谱已售罄或不可用"
	if state.heat < data.rules.recipe_price: return "热量不足"
	state.heat -= data.rules.recipe_price
	state.recipes.append(id)
	state.metrics.recipes.append(id)
	state.choices.erase(id)
	return ""
