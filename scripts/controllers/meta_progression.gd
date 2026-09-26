class_name MetaProgression
extends RefCounted

var saves: SaveService
var data: Catalog
var profile: Dictionary = {}
var error: String = ""

func _init(storage: SaveService, catalog: Catalog) -> void:
	saves = storage
	data = catalog

static func initial(data: Catalog) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.randomize()
	var meta: Dictionary = {"kills":0, "unlocked":[], "last_run":"", "inspiration":0, "cards":[], "loadout":[], "next_card":4, "offers":[], "refreshes":0, "rng":str(random.state), "ledger":{}, "last_action":{}}
	for index: int in range(3):
		var uid: String = "card_%d" % (index + 1)
		meta.cards.append({"uid":uid, "id":["bun","toast","pudding"][index], "level":0, "starter":true, "locked":false})
		meta.loadout.append(uid)
	roll_shop(meta, data)
	return meta

static func roll_shop(meta: Dictionary, data: Catalog) -> void:
	var random := RandomNumberGenerator.new()
	random.state = int(meta.rng)
	var ids: Array = data.foods.keys()
	meta.offers = []
	for index: int in range(data.progression.shop_slots):
		meta.offers.append({"id":ids[random.randi_range(0,ids.size()-1)], "bought":false})
	meta.rng = str(random.state)

static func card(meta: Dictionary, uid: String) -> Dictionary:
	for item: Dictionary in meta.cards:
		if item.uid == uid: return item
	return {}

static func loadout_error(meta: Dictionary, selected: Array, data: Catalog) -> String:
	if selected.is_empty() or selected.size() > data.progression.loadout_limit: return "请选择 1～%d 种美食" % data.progression.loadout_limit
	var kinds: Array = []
	var attack: bool = false
	for uid: Variant in selected:
		if not uid is String: return "卡片不存在"
		var item: Dictionary = card(meta, uid)
		if item.is_empty(): return "卡片不存在"
		if item.id in kinds: return "同种美食只能携带一张"
		kinds.append(item.id)
		attack = attack or data.foods[item.id].stats.damage > 0
	return "" if attack else "请至少携带一种能攻击的美食"

func reload(initialize: bool = true) -> bool:
	profile = saves.load_profile(data)
	error = saves.error
	if profile.is_empty() or not error.is_empty(): return false
	if initialize and not FileAccess.file_exists(saves.folder.path_join("player.json")):
		if not saves.commit_profile(profile, int(profile.revision)):
			error = saves.error
			return false
		profile = saves.load_profile(data)
	return true

func editable() -> bool:
	return not profile.is_empty() and profile.run.is_empty()

func begin(expected_revision: int) -> bool:
	if not reload(): return false
	if int(profile.revision) != expected_revision:
		error = "数据已更新，请重新选择后操作"
		return false
	if not editable():
		error = "请先继续或结束当前对局，再操作局外卡片"
		return false
	return true

func commit(title: String) -> String:
	profile.meta.last_action = {"text":title, "revision":int(profile.revision)+1}
	if not saves.commit_profile(profile, int(profile.revision)):
		error = saves.error
		profile = saves.load_profile(data)
		return error
	profile = saves.load_profile(data)
	error = ""
	return ""

func refresh_cost() -> int:
	if profile.is_empty(): return 0
	return data.progression.refresh_base * (1 << int(profile.meta.refreshes))

func buy(index: int, expected_revision: int) -> String:
	if not begin(expected_revision): return error
	var meta: Dictionary = profile.meta
	if index < 0 or index >= meta.offers.size() or meta.offers[index].bought: return "商品不存在或已售罄"
	if meta.inspiration < data.progression.card_price: return "灵感不足"
	meta.inspiration -= data.progression.card_price
	meta.cards.append({"uid":"card_%d" % int(meta.next_card), "id":meta.offers[index].id, "level":0, "starter":false, "locked":false})
	meta.next_card += 1
	meta.offers[index].bought = true
	return commit("购入 " + data.foods[meta.offers[index].id].title + " +0")

func refresh(expected_revision: int) -> String:
	if not begin(expected_revision): return error
	var meta: Dictionary = profile.meta
	if meta.refreshes >= data.progression.refresh_limit: return "本周期刷新已达安全上限"
	var cost: int = refresh_cost()
	if meta.inspiration < cost: return "灵感不足"
	meta.inspiration -= cost
	meta.refreshes += 1
	roll_shop(meta, data)
	return commit("卡店已刷新，花费 %d 灵感" % cost)

func toggle_lock(uid: String, expected_revision: int) -> String:
	if not begin(expected_revision): return error
	var item: Dictionary = card(profile.meta, uid)
	if item.is_empty(): return "卡片不存在"
	if item.starter: return "基础卡始终受保护，可以强化但不可作为耗材"
	item.locked = not item.locked
	return commit("已锁定卡片" if item.locked else "已解锁卡片")

func preview(uid: String, materials: Array) -> Dictionary:
	var result: Dictionary = {"error":"", "chance":0.0, "success_level":0, "failure_level":0}
	if profile.is_empty():
		result.error = "局外数据不可用"
		return result
	var main: Dictionary = card(profile.meta, uid)
	if main.is_empty():
		result.error = "请先选择主卡"
		return result
	result.success_level = int(main.level) + 1
	result.failure_level = int(main.level) if result.success_level <= data.progression.protected_target else int(main.level)-1
	if main.level >= data.progression.max_level: result.error = "主卡已满级"
	elif materials.size() < 1 or materials.size() > 3: result.error = "请选择 1～3 张材料卡"
	if not result.error.is_empty(): return result
	var seen: Array = []
	var contributions: Array[float] = []
	for material: Variant in materials:
		if not material is String or material == uid or material in seen:
			result.error = "主卡不能作为材料，材料不可重复"
			return result
		seen.append(material)
		var item: Dictionary = card(profile.meta, material)
		if item.is_empty() or item.starter or item.locked:
			result.error = "材料不存在、已锁定或为受保护基础卡"
			return result
		contributions.append(data.progression.material_base * pow(data.progression.material_decay, maxi(int(main.level)-int(item.level),0)))
	contributions.sort()
	for contribution: float in contributions: result.chance += contribution
	result.chance = clampf(result.chance,0.0,1.0)
	return result

func enhance(uid: String, materials: Array, expected_revision: int) -> String:
	if not begin(expected_revision): return error
	var result: Dictionary = preview(uid, materials)
	if not result.error.is_empty(): return result.error
	var meta: Dictionary = profile.meta
	var random := RandomNumberGenerator.new()
	random.state = int(meta.rng)
	var roll: float = random.randf()
	var success: bool = result.chance >= 1.0 or roll < result.chance
	meta.rng = str(random.state)
	var main: Dictionary = card(meta, uid)
	main.level = result.success_level if success else result.failure_level
	for material: String in materials:
		meta.cards.erase(card(meta, material))
		meta.loadout.erase(material)
	return commit("%s · %s +%d；已消耗 %d 张材料" % ["强化成功" if success else "强化失败", data.foods[main.id].title, int(main.level), materials.size()])
