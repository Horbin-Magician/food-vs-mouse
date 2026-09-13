class_name SaveService
extends RefCounted

const VERSION: int = 1
const FIELDS: Array[String] = ["wave","phase","coins","pantry","heat","cards","recipes","units","offers","choices","refreshes","repaired","leaks","elapsed","next_uid","metrics","run_id"]
var folder: String = "user://"
var error: String = ""

func write_json(name: String, payload: Dictionary) -> bool:
	error = ""
	var path: String = folder.path_join(name)
	var file: FileAccess = FileAccess.open(path + ".tmp",FileAccess.WRITE)
	if file == null:
		error = "无法写入存档：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"version":VERSION,"payload":payload}))
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status != OK:
		error = "存档写入未完成"
		return false
	if DirAccess.rename_absolute(path + ".tmp",path) != OK:
		error = "存档替换失败"
		return false
	return true

func read_json(name: String) -> Dictionary:
	error = ""
	var path: String = folder.path_join(name)
	if not FileAccess.file_exists(path): return {}
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null:
		error = "存档不可读取"
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version") != VERSION or not parsed.get("payload") is Dictionary:
		error = "存档损坏或版本不兼容，请重新开局"
		return {}
	return parsed.payload

func save_run(state: RunState, rng: RandomNumberGenerator) -> bool:
	if state.phase not in ["prepare","recipe"]:
		error = "仅准备阶段可保存"
		return false
	var payload: Dictionary = {"seed":str(state.seed_value),"rng":str(rng.state)}
	for field: String in FIELDS: payload[field] = state.get(field)
	return write_json("run.json",payload)

func load_run(data: Catalog) -> Dictionary:
	var payload: Dictionary = read_json("run.json")
	if payload.is_empty(): return {}
	if not validate(payload,data):
		error = "局内存档字段不合法，请重新开局；局外进度独立保留"
		return {}
	return payload

func restore(payload: Dictionary) -> RunState:
	var state: RunState = RunState.new()
	state.seed_value = int(payload.seed)
	for field: String in FIELDS: state.set(field,payload[field])
	state.cards = state.cards.duplicate(true)
	state.units = state.units.duplicate(true)
	state.metrics = state.metrics.duplicate(true)
	for id: String in state.cards: state.cards[id] = int(state.cards[id])
	for unit: Dictionary in state.units:
		for key: String in ["uid","row","col","attacks"]: unit[key] = int(unit[key])
	for key: String in ["kills","puddings","passed","leaks","deaths"]: state.metrics[key] = int(state.metrics[key])
	return state

func number(value: Variant, minimum: float, maximum: float, integer: bool = false) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]: return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and (not integer or floorf(value) == value)

func validate(p: Dictionary, data: Catalog) -> bool:
	for field: String in FIELDS:
		if not p.has(field): return false
	if not p.get("seed") is String or not p.seed.is_valid_int() or not p.get("rng") is String or not p.rng.is_valid_int(): return false
	if not p.run_id is String or p.run_id.is_empty() or p.run_id.length() > 80: return false
	if p.phase not in ["prepare","recipe"]: return false
	if not number(p.wave,1,8,true) or not number(p.coins,0,100000,true) or not number(p.pantry,1,10,true): return false
	if not number(p.heat,0,data.rules.heat_cap) or not number(p.refreshes,0,2,true) or not p.repaired is bool: return false
	if not number(p.leaks,0,1000,true) or not number(p.elapsed,0,1000000) or not number(p.next_uid,1,10000000,true): return false
	if not p.cards is Dictionary or not p.recipes is Array or not p.units is Array or not p.offers is Array or not p.choices is Array or not p.metrics is Dictionary: return false
	if p.cards.size() < 3 or p.units.size() > RunState.ROWS * RunState.COLS or p.offers.size() != 3 or p.choices.size() > 3: return false
	for initial: String in ["bun","toast","pudding"]:
		if not p.cards.has(initial): return false
	for id: Variant in p.cards:
		if not data.foods.has(id) or not number(p.cards[id],1,6,true): return false
	var seen: Array = []
	for id: Variant in p.recipes:
		if not data.recipes.has(id) or id in seen: return false
		seen.append(id)
	seen.clear()
	for id: Variant in p.choices:
		if not data.recipes.has(id) or id in p.recipes or id in seen: return false
		seen.append(id)
	for offer: Variant in p.offers:
		if not offer is Dictionary or not offer.get("bought") is bool or not offer.get("id") is String: return false
		if offer.id != "" and not data.foods.has(offer.id): return false
	seen.clear()
	var uids: Array = []
	for unit: Variant in p.units:
		if not unit is Dictionary or not p.cards.has(unit.get("id")): return false
		if not number(unit.get("row"),0,RunState.ROWS-1,true) or not number(unit.get("col"),0,RunState.COLS-1,true): return false
		var cell: int = int(unit.row)*RunState.COLS+int(unit.col)
		if cell in seen or unit.get("uid") in uids or not number(unit.get("uid"),1,p.next_uid-1,true): return false
		seen.append(cell)
		uids.append(unit.uid)
		var star: int = 2 if p.cards[unit.id] >= 6 else (1 if p.cards[unit.id] >= 3 else 0)
		if not number(unit.get("hp"),0.00001,data.foods[unit.id].stats.hp*data.rules.star_hp[star]): return false
		for key: String in ["timer","attacks","flour","flash"]:
			if not number(unit.get(key),0,1000000): return false
	for key: String in ["kills","puddings","passed","leaks","deaths","overflow"]:
		if not number(p.metrics.get(key),0,100000000): return false
	if not p.metrics.get("damage") is Dictionary or not p.metrics.get("recipes") is Array: return false
	for id: Variant in p.metrics.damage:
		if not data.foods.has(id) or not number(p.metrics.damage[id],0,1e12): return false
	return p.metrics.recipes == p.recipes

func delete_run() -> void:
	if FileAccess.file_exists(folder.path_join("run.json")):
		if DirAccess.remove_absolute(folder.path_join("run.json")) != OK: error = "旧快照移除失败"

func load_meta(data: Catalog) -> Dictionary:
	var p: Dictionary = read_json("meta.json")
	if p.is_empty(): return {"kills":0,"unlocked":[],"last_run":""}
	if not number(p.get("kills"),0,1e12,true) or not p.get("unlocked") is Array or not p.get("last_run") is String:
		error = "局外进度损坏，当前暂按初始解锁运行"
		return {"kills":0,"unlocked":[],"last_run":""}
	for id: Variant in p.unlocked:
		if not data.recipes.has(id):
			error = "局外进度含未知食谱"
			return {"kills":0,"unlocked":[],"last_run":""}
	return p

func settle(state: RunState, data: Catalog) -> bool:
	var meta: Dictionary = load_meta(data)
	if not error.is_empty(): return false
	if meta.last_run != state.run_id:
		meta.kills += state.metrics.kills
		for id: String in data.recipes:
			var stats: Dictionary = data.recipes[id].stats
			if not stats.has("unlock") or id in meta.unlocked: continue
			var count: float = meta.kills if stats.unlock == "kills" else state.metrics.get(stats.unlock,0)
			if count >= stats.threshold: meta.unlocked.append(id)
		meta.last_run = state.run_id
		if DirAccess.make_dir_recursive_absolute(folder.path_join("runs")) != OK:
			error = "无法创建局记录目录"
			return false
		if not write_json("runs/" + state.run_id.sha256_text() + ".json",{"seed":str(state.seed_value),"wave":state.wave,"phase":state.phase,"elapsed":state.elapsed,"metrics":state.metrics}): return false
		if not write_json("meta.json",meta): return false
	delete_run()
	return error.is_empty()
