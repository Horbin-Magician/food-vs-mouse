class_name ShopController
extends RefCounted

signal card_upgraded(food_id: String, star: int)
var state: RunState
var data: Catalog
var board: BoardController
var rng: RandomNumberGenerator

func _init(s: RunState, c: Catalog, b: BoardController, random: RandomNumberGenerator) -> void:
	state = s
	data = c
	board = b
	rng = random

func open() -> void:
	state.refreshes = 0
	generate()

func generate() -> void:
	state.offers.clear()
	var pool: Array = []
	for id: String in data.foods:
		if state.cards.get(id,0) < 6: pool.append(id)
	for i: int in range(3):
		state.offers.append({"id": pool[rng.randi_range(0,pool.size()-1)] if not pool.is_empty() else "", "bought": false})

func buy(index: int) -> String:
	if state.phase != "prepare": return "仅准备阶段可购买"
	if index < 0 or index >= state.offers.size(): return "商品不存在"
	var offer: Dictionary = state.offers[index]
	if offer.bought or offer.id.is_empty() or state.cards.get(offer.id,0) >= 6: return "商品已售罄"
	var price: int = data.foods[offer.id].stats.price
	if state.coins < price: return "金币不足"
	var previous_hp: float = board.max_hp(offer.id)
	var previous_star: int = state.star(offer.id)
	state.coins -= price
	offer.bought = true
	state.cards[offer.id] = state.cards.get(offer.id,0) + 1
	if state.star(offer.id) != previous_star:
		for unit: Dictionary in state.units:
			if unit.id == offer.id: unit.hp += board.max_hp(offer.id) - previous_hp
		card_upgraded.emit(offer.id,state.star(offer.id))
	return ""

func refresh() -> String:
	if state.phase != "prepare": return "仅准备阶段可刷新"
	if state.refreshes >= data.rules.refresh_limit: return "刷新次数已用完"
	if state.coins < data.rules.refresh_cost: return "金币不足"
	state.coins -= data.rules.refresh_cost
	state.refreshes += 1
	generate()
	return ""
