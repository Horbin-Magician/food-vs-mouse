class_name SaveService
extends RefCounted

const VERSION: int = 1
const FIELDS: Array[String] = ["inspiration_earned","inspiration_collected","difficulty","wave","phase","pantry","heat","cards","recipes","units","offers","choices","refreshes","repaired","leaks","elapsed","next_uid","metrics","run_id","loadout","levels","legacy_stars","reward_floor","rewards_enabled"]
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

func run_payload(state: RunState, rng: RandomNumberGenerator) -> Dictionary:
	var payload: Dictionary = {"seed":str(state.seed_value), "rng":str(rng.state)}
	for field: String in FIELDS: payload[field] = state.get(field)
	return payload.duplicate(true)

func save_run(state: RunState, rng: RandomNumberGenerator) -> bool:
	if state.phase not in ["prepare", "recipe"]:
		error = "仅准备阶段可保存"
		return false
	var data := Catalog.new()
	var payload: Dictionary = run_payload(state,rng)
	if not validate(payload,data):
		error = "拒绝保存非法局内状态"
		return false
	var profile: Dictionary = load_profile(data)
	if profile.is_empty() or not error.is_empty(): return false
	if profile.meta.ledger.get(state.run_id, {}).get("settled", false):
		error = "这局已结算，不能恢复旧快照"
		return false
	if not profile.run.is_empty() and profile.run.get("run_id",state.run_id) != state.run_id:
		error = "已有另一局存档，请先结束旧局"
		return false
	profile.run = payload
	if not state.legacy_stars:
		profile.meta.loadout = []
		for item: Dictionary in state.loadout: profile.meta.loadout.append(item.uid)
	credit(profile.meta, state, data)
	profile.run.inspiration_collected = profile.meta.ledger[state.run_id].inspiration_collected.duplicate(true)
	if not validate_collected(profile.run.inspiration_collected, state.wave):
		error = "收集记录已进入后续关卡，不能保存旧快照"
		return false
	if not commit_profile(profile, int(profile.revision)): return false
	state.inspiration_collected = profile.run.inspiration_collected.duplicate(true)
	return true

func load_run(data: Catalog) -> Dictionary:
	var profile: Dictionary = load_profile(data)
	if profile.is_empty(): return {}
	var payload: Dictionary = profile.run
	if payload.is_empty(): return {}
	if not validate(payload, data):
		error = "局内存档字段不合法，请重新开局；局外进度独立保留"
		return {}
	if profile.meta.ledger.get(payload.run_id, {}).get("settled", false):
		error = "对局已结算，请开始新局"
		return {}
	payload["inspiration_collected"] = collected_maximum(payload.get("inspiration_collected", {}), profile.meta.ledger.get(payload.run_id, {}).get("inspiration_collected", {}))
	if not validate_collected(payload.inspiration_collected, int(payload.wave)):
		error = "收集记录与局内关卡不一致，请重新开局；局外灵感保留"
		return {}
	return payload

func restore(payload: Dictionary) -> RunState:
	var state: RunState = RunState.new()
	state.seed_value = int(payload.seed)
	for field: String in FIELDS:
		if field in ["inspiration_earned", "inspiration_collected"]: state.set(field, payload.get(field, {}).duplicate(true))
		else: state.set(field,payload.get(field, "easy") if field == "difficulty" else payload[field])
	state.cards = state.cards.duplicate(true)
	state.units = state.units.duplicate(true)
	state.metrics = state.metrics.duplicate(true)
	state.levels = state.levels.duplicate(true)
	state.loadout = state.loadout.duplicate(true)
	for id: String in state.cards: state.cards[id] = int(state.cards[id])
	for unit: Dictionary in state.units:
		for key: String in ["uid","row","col","attacks"]: unit[key] = int(unit[key])
	for key: String in ["kills","puddings","passed","leaks","deaths"]: state.metrics[key] = int(state.metrics[key])
	return state

func number(value: Variant, minimum: float, maximum: float, integer: bool = false) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT]: return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and (not integer or floorf(value) == value)

func validate(p: Dictionary, data: Catalog) -> bool:
	if not p.get("difficulty", "easy") is String or not data.difficulties.has(p.get("difficulty", "easy")): return false
	for field: String in FIELDS:
		if field not in ["difficulty", "inspiration_earned", "inspiration_collected"] and not p.has(field): return false
	if not p.get("seed") is String or not p.seed.is_valid_int() or not p.get("rng") is String or not p.rng.is_valid_int(): return false
	if not p.run_id is String or p.run_id.is_empty() or p.run_id.length() > 80: return false
	if p.phase not in ["prepare","recipe"]: return false
	if not number(p.wave,1,8,true) or not number(p.pantry,1,10,true): return false
	if not number(p.heat,0,data.rules.heat_cap) or not number(p.refreshes,0,2,true) or not p.repaired is bool: return false
	if not number(p.leaks,0,1000,true) or not number(p.elapsed,0,1000000) or not number(p.next_uid,1,10000000,true): return false
	if not p.cards is Dictionary or not p.recipes is Array or not p.units is Array or not p.offers is Array or not p.choices is Array or not p.metrics is Dictionary: return false
	if p.cards.is_empty() or p.units.size() > RunState.ROWS * RunState.COLS or not p.offers.is_empty() or p.choices.size() > 3: return false
	if not p.legacy_stars is bool or not p.rewards_enabled is bool or not p.levels is Dictionary or not p.loadout is Array: return false
	if not number(p.reward_floor,0,8,true): return false
	if not p.legacy_stars and p.cards.size() > data.progression.loadout_limit: return false
	for id: Variant in p.levels:
		if not p.cards.has(id) or not number(p.levels[id],0,data.progression.max_level,true): return false
	if not p.legacy_stars:
		if p.loadout.size() != p.cards.size() or p.levels.size() != p.cards.size(): return false
		var loadout_ids: Array = []
		var loadout_kinds: Array = []
		for item: Variant in p.loadout:
			if not item is Dictionary or not item.get("uid") is String or not p.cards.has(item.get("id")): return false
			if item.uid.is_empty() or item.uid in loadout_ids or item.id in loadout_kinds: return false
			if not number(item.get("level"),0,data.progression.max_level,true) or item.level != p.levels[item.id]: return false
			loadout_ids.append(item.uid)
			loadout_kinds.append(item.id)
	for id: Variant in p.cards:
		if not data.foods.has(id) or not number(p.cards[id],1,6 if p.legacy_stars else 1,true): return false
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
		var multiplier: float = data.rules.star_hp[star] if p.legacy_stars else 1.0 + float(p.levels.get(unit.id,0)) * data.progression.stat_per_level
		if not number(unit.get("hp"),0.00001,data.foods[unit.id].stats.hp*multiplier + 0.0001): return false
		for key: String in ["timer","attacks","flour","flash"]:
			if not number(unit.get(key),0,1000000): return false
	for key: String in ["kills","puddings","passed","leaks","deaths","overflow"]:
		if not number(p.metrics.get(key),0,100000000): return false
	if not number(p.metrics.passed,0,8,true) or p.reward_floor > p.metrics.passed: return false
	if not p.get("inspiration_earned", {}) is Dictionary: return false
	for key: Variant in p.get("inspiration_earned", {}):
		if not key is String or key not in ["1","2","3","4","5","6","7","8"] or int(key) > p.metrics.passed: return false
		if not number(p.inspiration_earned[key],0,1000000,true): return false
	if not validate_collected(p.get("inspiration_collected", {}), int(p.wave)): return false
	if not p.metrics.get("damage") is Dictionary or not p.metrics.get("recipes") is Array: return false
	for id: Variant in p.metrics.damage:
		if not data.foods.has(id) or not number(p.metrics.damage[id],0,1e12): return false
	return p.metrics.recipes == p.recipes

func delete_run() -> void:
	if FileAccess.file_exists(folder.path_join("player.json")):
		var profile: Dictionary = load_profile(Catalog.new())
		if profile.is_empty(): return
		profile.run = {}
		commit_profile(profile, int(profile.revision))
	elif FileAccess.file_exists(folder.path_join("run.json")):
		if DirAccess.remove_absolute(folder.path_join("run.json")) != OK: error = "旧快照移除失败"

func load_meta(data: Catalog) -> Dictionary:
	var profile: Dictionary = load_profile(data)
	return profile.meta if not profile.is_empty() else {"kills":0,"unlocked":[],"last_run":""}

func load_profile(data: Catalog) -> Dictionary:
	error = ""
	if FileAccess.file_exists(folder.path_join("player.json")):
		var file := FileAccess.open(folder.path_join("player.json"), FileAccess.READ)
		if file == null:
			error = "局外存档不可读取，未覆盖原文件"
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or parsed.get("version") != 2 or not parsed.get("payload") is Dictionary:
			error = "局外存档损坏或版本不兼容，未覆盖原文件"
			return {}
		var profile: Dictionary = parsed.payload
		if not number(profile.get("revision"),0,1e12,true) or not profile.get("run") is Dictionary or not profile.get("meta") is Dictionary or not validate_meta(profile.meta, data):
			error = "局外进度字段不合法，未覆盖原文件"
			return {}
		return profile
	var old_meta: Dictionary = read_json("meta.json")
	if not error.is_empty(): return {}
	if old_meta.is_empty() and FileAccess.file_exists(folder.path_join("meta.json")):
		error = "旧局外进度为空或损坏，未覆盖原文件"
		return {}
	var meta: Dictionary = MetaProgression.initial(data)
	if not old_meta.is_empty():
		if not number(old_meta.get("kills"),0,1e12,true) or not old_meta.get("unlocked") is Array or not old_meta.get("last_run") is String:
			error = "旧局外进度损坏，未迁移或覆盖"
			return {}
		for id: Variant in old_meta.unlocked:
			if not data.recipes.has(id):
				error = "旧局外进度含未知食谱"
				return {}
		for key: String in ["kills","unlocked","last_run"]: meta[key] = old_meta[key]
		if not meta.last_run.is_empty(): meta.ledger[meta.last_run] = {"passed":0,"settled":true}
	var old_run: Dictionary = read_json("run.json")
	var run_error: String = error
	if not old_run.is_empty():
		old_run["loadout"] = []
		old_run["levels"] = {}
		old_run["legacy_stars"] = true
		old_run["reward_floor"] = int(old_run.metrics.get("passed",0)) if old_run.get("metrics") is Dictionary and number(old_run.metrics.get("passed"),0,8,true) else 0
		old_run["rewards_enabled"] = true
		old_run["offers"] = []
		if not validate(old_run, data): run_error = "旧局内存档字段不合法，请重新开局；局外进度保留"
	# Keep invalid run data separate from valid assets; new game may replace it explicitly.
	if not run_error.is_empty(): old_run = {"invalid":true}
	error = ""
	return {"revision":0, "meta":meta, "run":old_run}

func commit_profile(profile: Dictionary, expected_revision: int) -> bool:
	var data := Catalog.new()
	var current: Dictionary = load_profile(data)
	if current.is_empty() or not error.is_empty(): return false
	if int(current.revision) != expected_revision:
		error = "存档已更新，请重试当前操作"
		return false
	if not validate_meta(profile.meta, data):
		error = "拒绝保存非法局外数据"
		return false
	var copy: Dictionary = profile.duplicate(true)
	copy.revision = expected_revision + 1
	var path: String = folder.path_join("player.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法写入局外存档：" + error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify({"version":2,"payload":copy}))
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status != OK or DirAccess.rename_absolute(path + ".tmp",path) != OK:
		error = "局外存档保存失败，操作未提交"
		return false
	error = ""
	return true

func validate_meta(meta: Dictionary, data: Catalog) -> bool:
	for key: String in ["kills","inspiration","next_card","refreshes"]:
		if not number(meta.get(key),0,1e12,true): return false
	if meta.next_card < 4 or meta.refreshes > data.progression.refresh_limit: return false
	if not meta.get("rng") is String or not meta.rng.is_valid_int() or not meta.get("last_run") is String: return false
	if not meta.get("cards") is Array or not meta.get("loadout") is Array or not meta.get("offers") is Array or not meta.get("unlocked") is Array or not meta.get("ledger") is Dictionary or not meta.get("last_action") is Dictionary: return false
	if meta.offers.size() != data.progression.shop_slots: return false
	var seen: Array = []
	var starters: Array = []
	for item: Variant in meta.cards:
		if not item is Dictionary or not item.get("uid") is String or not data.foods.has(item.get("id")): return false
		if item.uid in seen or not item.uid.begins_with("card_") or not item.uid.trim_prefix("card_").is_valid_int(): return false
		if int(item.uid.trim_prefix("card_")) < 1 or int(item.uid.trim_prefix("card_")) >= meta.next_card: return false
		seen.append(item.uid)
		if not number(item.get("level"),0,data.progression.max_level,true) or not item.get("starter") is bool or not item.get("locked") is bool: return false
		if item.starter:
			if item.id not in ["bun","toast","pudding"] or item.id in starters: return false
			starters.append(item.id)
	if starters.size() != 3: return false
	for uid: Variant in meta.loadout:
		if uid not in seen: return false
	for offer: Variant in meta.offers:
		if not offer is Dictionary or not data.foods.has(offer.get("id")) or not offer.get("bought") is bool: return false
	seen.clear()
	for id: Variant in meta.unlocked:
		if not data.recipes.has(id) or id in seen: return false
		seen.append(id)
	for id: Variant in meta.ledger:
		var entry: Variant = meta.ledger[id]
		if not id is String or not entry is Dictionary or not number(entry.get("passed"),0,8,true) or not entry.get("settled") is bool: return false
		if not validate_collected(entry.get("inspiration_collected", {})): return false
	return true

func validate_collected(value: Variant, maximum_wave: int = 8) -> bool:
	if not value is Dictionary: return false
	for key: Variant in value:
		if not key is String or key not in ["1","2","3","4","5","6","7","8"]: return false
		if int(key) > maximum_wave: return false
		if not number(value[key],0,1000000,true): return false
	return true

func collected_maximum(first: Dictionary, second: Dictionary) -> Dictionary:
	var result: Dictionary = first.duplicate(true)
	for key: String in second: result[key] = maxi(int(result.get(key, 0)), int(second[key]))
	return result

func collect_inspiration(state: RunState, wave_total: int, data: Catalog) -> bool:
	error = ""
	if state.phase != "battle" or not state.rewards_enabled:
		error = "当前对局不能收取灵感"
		return false
	if not number(wave_total,0,1000000,true) or not validate_collected(state.inspiration_collected, state.wave):
		error = "灵感收集记录不合法"
		return false
	var profile: Dictionary = load_profile(data)
	if profile.is_empty() or not error.is_empty(): return false
	if not validate(profile.run, data) or profile.run.run_id != state.run_id or int(profile.run.wave) != state.wave or int(profile.run.seed) != state.seed_value or not profile.run.rewards_enabled:
		error = "对局快照已变化，灵感未收取"
		return false
	var entry: Dictionary = profile.meta.ledger.get(state.run_id, {"passed":state.reward_floor,"settled":false})
	if entry.settled:
		error = "这局已结算，灵感未收取"
		return false
	var collected: Dictionary = entry.get("inspiration_collected", {}).duplicate(true)
	if not validate_collected(collected, state.wave):
		error = "收集记录已进入后续关卡，灵感未收取"
		return false
	var key: String = str(state.wave)
	var previous: int = int(collected.get(key, 0))
	if wave_total <= previous:
		state.inspiration_collected = collected_maximum(state.inspiration_collected, collected)
		return true
	collected[key] = wave_total
	entry["inspiration_collected"] = collected
	profile.meta.ledger[state.run_id] = entry
	profile.meta.inspiration += wave_total - previous
	# Preserve the preparation board, heat and RNG; only collection metadata changes.
	profile.run["inspiration_collected"] = collected_maximum(profile.run.get("inspiration_collected", {}), collected)
	if not commit_profile(profile, int(profile.revision)): return false
	state.inspiration_collected = collected_maximum(state.inspiration_collected, collected)
	return true

func credit(meta: Dictionary, state: RunState, data: Catalog) -> void:
	var entry: Dictionary = meta.ledger.get(state.run_id, {"passed":state.reward_floor,"settled":false})
	if entry.settled: return
	entry["inspiration_collected"] = collected_maximum(entry.get("inspiration_collected", {}), state.inspiration_collected)
	if state.rewards_enabled:
		for index: int in range(int(entry.passed), mini(int(state.metrics.passed),8)):
			meta.inspiration += state.inspiration_for_wave(index, data)
	entry.passed = maxi(int(entry.passed), int(state.metrics.passed))
	meta.ledger[state.run_id] = entry

func settle(state: RunState, data: Catalog) -> bool:
	var profile: Dictionary = load_profile(data)
	if profile.is_empty() or not error.is_empty(): return false
	var meta: Dictionary = profile.meta
	if meta.ledger.get(state.run_id,{}).get("settled",false):
		state.inspiration_collected = collected_maximum(state.inspiration_collected, meta.ledger[state.run_id].get("inspiration_collected", {}))
		return true
	if not profile.run.is_empty() and profile.run.get("run_id",state.run_id) != state.run_id:
		error = "对局已变化，不能结算旧请求"
		return false
	credit(meta,state,data)
	if state.rewards_enabled:
		meta.kills += state.metrics.kills
		for id: String in data.recipes:
			var stats: Dictionary = data.recipes[id].stats
			if not stats.has("unlock") or id in meta.unlocked: continue
			var count: float = meta.kills if stats.unlock == "kills" else state.metrics.get(stats.unlock,0)
			if count >= stats.threshold: meta.unlocked.append(id)
	meta.last_run = state.run_id
	meta.ledger[state.run_id].settled = true
	meta.ledger[state.run_id]["summary"] = {"seed":str(state.seed_value),"phase":state.phase,"elapsed":state.elapsed,"metrics":state.metrics.duplicate(true),"inspiration_collected":meta.ledger[state.run_id].inspiration_collected.duplicate(true)}
	if state.rewards_enabled:
		MetaProgression.roll_shop(meta,data)
		meta.refreshes = 0
	profile.run = {}
	if not commit_profile(profile,int(profile.revision)): return false
	state.inspiration_collected = meta.ledger[state.run_id].inspiration_collected.duplicate(true)
	return true
