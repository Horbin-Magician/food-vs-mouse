class_name Catalog
extends RefCounted

var progression: ProgressionDef = preload("res://resources/progression.tres")
var difficulties: Dictionary = {}
var foods: Dictionary = {}
var enemies: Dictionary = {}
var recipes: Dictionary = {}
var chapters: Dictionary = {}
var scenes: Dictionary = {}
var waves: Array[Resource] = []
var rules: Dictionary = preload("res://resources/rules.tres").stats

func _init() -> void:
	for id: String in ["easy", "normal", "hard"]:
		var definition: DifficultyDef = load("res://resources/difficulties/" + id + ".tres")
		assert(definition.id == id)
		difficulties[id] = definition
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

	for index: int in range(1, 6):
		var chapter: ChapterDef = load("res://resources/chapters/kitchen_%d.tres" % index)
		assert(not chapters.has(chapter.id))
		chapters[chapter.id] = chapter
	var kitchen: ScenarioDef = preload("res://resources/scenarios/kitchen.tres")
	scenes[kitchen.id] = kitchen
	assert(validate().is_empty(),str(validate()))

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: String in chapters:
		var chapter: ChapterDef = chapters[id]
		if chapter.id != id or chapter.order < 1 or chapter.first_clear_reward < 0: errors.append(id + ": invalid chapter")
		if chapter.available and chapter.waves.size() != 8: errors.append(id + ": eight waves required")
		var seen: Array = []
		for wave: Resource in chapter.waves:
			if not wave is WaveDef or wave.id in seen: errors.append(id + ": invalid wave reference")
			else: seen.append(wave.id)
	for id: String in scenes:
		var scene: ScenarioDef = scenes[id]
		if scene.id != id or scene.chapter_ids.is_empty(): errors.append(id + ": invalid scene")
		var seen: Array[String] = []
		for index: int in range(scene.chapter_ids.size()):
			var chapter_id: String = scene.chapter_ids[index]
			if not chapters.has(chapter_id) or chapter_id in seen:
				errors.append(id + ": invalid chapter reference")
			elif chapters[chapter_id].order != index + 1:
				errors.append(id + ": invalid chapter order")
			seen.append(chapter_id)
	for id: String in difficulties:
		var difficulty: DifficultyDef = difficulties[id]
		for multiplier: float in [difficulty.hp_multiplier, difficulty.damage_multiplier, difficulty.reward_multiplier]:
			if not is_finite(multiplier) or multiplier <= 0: errors.append(id + ": invalid difficulty multiplier")
		if not is_finite(difficulty.inspiration_drop_chance) or difficulty.inspiration_drop_chance < 0 or difficulty.inspiration_drop_chance > 1:
			errors.append(id + ": invalid inspiration drop chance")
	var summon_interval: float = rules.get("boss_summon_interval", 0.0)
	var rage_interval: float = rules.get("boss_rage_summon_interval", 0.0)
	if not is_finite(summon_interval) or not is_finite(rage_interval) or summon_interval <= 0 or rage_interval <= 0 or rage_interval > summon_interval:
		errors.append("invalid boss summon intervals")
	if progression.loadout_limit < 1 or progression.loadout_limit > 8 or progression.max_level < 7: errors.append("invalid progression limits")
	if progression.card_price <= 0 or progression.refresh_base <= 0 or progression.refresh_limit > 30: errors.append("invalid progression prices")
	if progression.inspiration_rewards.size() != 8: errors.append("eight inspiration rewards required")
	for reward: int in progression.inspiration_rewards:
		if reward < 0: errors.append("negative inspiration reward")
	if progression.inspiration_drop_amount <= 0: errors.append("invalid inspiration drop amount")
	if not is_finite(progression.inspiration_flight_duration) or progression.inspiration_flight_duration <= 0:
		errors.append("invalid inspiration flight duration")
	if progression.material_base <= 0 or progression.material_base > 1 or progression.material_decay <= 0 or progression.material_decay > 1: errors.append("invalid enhancement probability")
	for id: String in foods:
		var stats: Dictionary = foods[id].stats
		for key: String in ["cost","cooldown","hp","damage","interval","reach","price"]:
			if not stats.has(key) or not stats[key] is float and not stats[key] is int or stats.get(key,-1) < 0: errors.append(id + ": " + key)
		if stats.get("hp",0) <= 0 or stats.get("cost",0) <= 0: errors.append(id + ": positive hp/cost required")
	for id: String in enemies:
		var enemy: EnemyDef = enemies[id]
		if enemy.rank not in ["normal", "elite", "boss"]: errors.append(id + ": invalid rank")
		if enemy.art_id.is_empty(): errors.append(id + ": missing art ID")
		for key: String in ["hp","speed","dps","leak"]:
			if not positive_number(enemy.stats.get(key)): errors.append(id + ": " + key)
		var expected_leak: int = 10 if enemy.rank == "boss" else 2 if enemy.rank == "elite" else 1
		if enemy.stats.get("leak") != expected_leak: errors.append(id + ": rank/leak mismatch")
		if enemy.stats.has("armor_hits") and (not enemy.stats.armor_hits is int or enemy.stats.armor_hits <= 0 or not positive_number(enemy.stats.get("armor"))):
			errors.append(id + ": invalid finite armor")
		validate_enemy_skills(enemy, errors)
	for id: String in recipes:
		var required: String = recipes[id].stats.get("requires","")
		if required not in ["","area"] and not foods.has(required): errors.append(id + ": missing food")
	var checked_waves: Array[Resource] = waves.duplicate()
	for chapter: ChapterDef in chapters.values():
		for definition: Resource in chapter.waves:
			if not checked_waves.has(definition): checked_waves.append(definition)
	for wave: Resource in checked_waves:
		if not is_finite(wave.spawn_rate) or wave.spawn_rate <= 0: errors.append(wave.id + ": invalid spawn rate")
		if wave.stats.get("composition",[]).is_empty() or wave.stats.get("duration",0) < 5: errors.append(wave.id + ": empty wave")
		var boss_count: int = 0
		var elite_count: int = 0
		for id: String in wave.stats.get("composition",[]):
			if not enemies.has(id): errors.append(wave.id + ": missing enemy " + id)
			if is_boss(id):
				boss_count += 1
				if id != wave.stats.get("boss_id", "boss"): errors.append(wave.id + ": unconfigured boss")
			if is_elite(id): elite_count += 1
		if boss_count + elite_count > 1: errors.append(wave.id + ": one special enemy per wave")
		for field: String in ["boss_id", "elite_id"]:
			if wave.stats.has(field):
				var id: String = wave.stats[field]
				var expected: String = "boss" if field == "boss_id" else "elite"
				if enemy_rank(id) != expected or wave.stats.composition.count(id) != 1 or wave.stats.composition.back() != id:
					errors.append(wave.id + ": invalid " + field)
		if wave.stats.has("boss_id") and wave.stats.has("boss"): errors.append(wave.id + ": independent boss cannot use legacy summons")
		if wave.stats.has("boss"):
			var boss: Dictionary = wave.stats.boss
			for key: String in ["normal_id", "rage_id", "burst_id"]:
				if not enemies.has(boss.get(key)) or is_boss(boss.get(key, "")): errors.append(wave.id + ": invalid summon enemy")
			for key: String in ["interval", "rage_interval", "warning_seconds"]:
				var value: float = boss.get(key, 0.0)
				if not is_finite(value) or value <= 0: errors.append(wave.id + ": invalid boss timing")
			if boss.get("rage_interval", 0.0) > boss.get("interval", 0.0): errors.append(wave.id + ": invalid rage interval")
			var boss_rows: Array = boss.get("rows", [])
			if boss_rows.size() != 2 or boss_rows[0] == boss_rows[1]: errors.append(wave.id + ": two summon rows required")
			for row: Variant in boss_rows:
				if not row is int or row < 0 or row >= RunState.ROWS: errors.append(wave.id + ": invalid summon row")
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
				if wave.stats.get("balanced_lanes", false):
					var excluded: Array = batch.get("exclude_rows", [])
					var excluded_unique: Dictionary = {}
					for row: Variant in excluded:
						if not row is int or row not in rows: errors.append(wave.id + ": invalid excluded row")
						excluded_unique[row] = true
					if excluded_unique.size() != excluded.size() or rows.size() - excluded.size() < 4:
						errors.append(wave.id + ": insufficient balanced rows")
					if lanes.size() == 1:
						if count >= wave.stats.composition.size() or enemy_rank(wave.stats.composition[count]) not in ["elite", "boss"]:
							errors.append(wave.id + ": singleton batch must be special")
					elif lanes.size() < 3 or lanes[0] != 0 or lanes[1] != 1 or lanes[2] != 2:
						errors.append(wave.id + ": balanced batch must start on three lanes")
					if batch.has("avoid_previous_ids"):
						if lanes.size() != 1 or not excluded.is_empty(): errors.append(wave.id + ": avoidance only allowed for a special batch")
						for id: String in batch.avoid_previous_ids:
							if not enemies.has(id): errors.append(wave.id + ": missing avoided enemy")
				for i: int in range(lanes.size()):
					if not lanes[i] is int or lanes[i] < 0 or lanes[i] > 2: errors.append(wave.id + ": invalid lane slot")
					if i >= 2 and lanes[i] == lanes[i-1] and lanes[i] == lanes[i-2]: errors.append(wave.id + ": lane streak")
				if count == 0 and (lanes.size() < 3 or lanes[0] == lanes[1] or lanes[1] == lanes[2] or lanes[0] == lanes[2]):
					errors.append(wave.id + ": first three lanes must differ")
				count += lanes.size()
				last_time = start + (lanes.size() - 1) * gap
			if count != wave.stats.composition.size(): errors.append(wave.id + ": batch count mismatch")
	return errors

func enemy_rank(id: String) -> String:
	return enemies[id].rank if enemies.has(id) else ""

func is_boss(id: String) -> bool:
	return enemy_rank(id) == "boss"

func is_elite(id: String) -> bool:
	return enemy_rank(id) == "elite"

func positive_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0

func validate_enemy_skills(enemy: EnemyDef, errors: PackedStringArray) -> void:
	var required: Dictionary = {
		"legacy": [],
		"skater": ["interval", "windup", "dash_speed", "dash_duration", "recovery_speed", "recovery", "segments"],
		"scout": ["windup", "entrance_min", "entrance_max", "clearance"],
		"rivet": ["unarmored_speed"],
		"breaker": ["interval", "windup", "damage", "recovery"],
		"acid": ["interval", "windup", "reach", "damage", "tick_damage", "tick_interval", "ground_duration", "max_rows"],
		"dough": ["interval", "windup", "shield", "shield_duration"],
		"ration": ["interval", "windup", "reach", "shield", "shield_duration", "supplies"],
		"skewer": ["splash_reach", "splash_ratio"],
		"windwhistle": ["interval", "rage_interval", "threshold", "windup", "dash_speed", "dash_duration", "damage", "recovery", "rage_recovery", "exposed"],
		"ironpot": ["shield", "interval", "rage_interval", "threshold", "windup", "damage", "recovery", "exposure_duration", "exposed"],
		"starter": ["interval", "reach", "windup", "ground_duration", "damage", "recovery", "exposed", "threshold", "max_targets", "rage_max_targets", "slow_penalty"],
		"quartermaster": ["initial_delay", "windup", "order_gap", "observation", "failure_duration", "exposed", "shield", "shield_duration"]
	}
	var id: String = enemy.id
	var skills: Dictionary = enemy.skills
	if not required.has(enemy.behavior_id):
		errors.append(id + ": unknown behavior")
		return
	for key: String in required[enemy.behavior_id]:
		if not positive_number(skills.get(key)): errors.append(id + ": invalid skill " + key)
	for key: String in skills:
		var value: Variant = skills[key]
		if value is int or value is float:
			if not is_finite(float(value)) or float(value) < 0: errors.append(id + ": invalid numeric skill " + key)
		if key in ["threshold", "splash_ratio", "slow_penalty"] and (not positive_number(value) or float(value) >= 1.0):
			errors.append(id + ": invalid skill ratio " + key)
	if enemy.behavior_id != "legacy" and (enemy.description.is_empty() or enemy.story.is_empty() or enemy.hint.is_empty()):
		errors.append(id + ": new enemy needs readable identity")
	if enemy.behavior_id in ["windwhistle", "ironpot", "starter", "quartermaster"] and enemy.rank != "boss":
		errors.append(id + ": boss behavior requires boss rank")
	for key: String in ["segments", "max_rows", "max_targets", "rage_max_targets", "supplies"]:
		if skills.has(key) and (not skills[key] is int or skills[key] < 1): errors.append(id + ": invalid skill count " + key)
	if skills.has("exposed") and (not positive_number(skills.exposed) or float(skills.exposed) <= 1.0):
		errors.append(id + ": exposed multiplier must increase damage")
	if enemy.behavior_id == "skater":
		if skills.get("segments") not in [1, 2] or not skills.has("segment_pause") or not (skills.segment_pause is int or skills.segment_pause is float):
			errors.append(id + ": invalid dash segments")
		elif skills.segments > 1 and not positive_number(skills.segment_pause): errors.append(id + ": missing segment pause")
	if enemy.behavior_id == "scout" and float(skills.get("entrance_min", 0)) >= float(skills.get("entrance_max", 0)):
		errors.append(id + ": invalid entrance range")
	if enemy.behavior_id == "rivet" and not enemy.stats.has("armor_hits"): errors.append(id + ": rivet needs finite armor")
	if enemy.behavior_id == "quartermaster":
		var thresholds: Array = skills.get("thresholds", [])
		if thresholds.size() != 2 or not positive_number(thresholds[0]) or not positive_number(thresholds[1]) or thresholds[0] >= 1 or thresholds[0] <= thresholds[1]:
			errors.append(id + ": invalid order thresholds")
		var order_ids: Array = skills.get("order_ids", [])
		if order_ids.size() != 3: errors.append(id + ": three finite orders required")
		for order_id: String in order_ids:
			if enemy_rank(order_id) != "normal": errors.append(id + ": invalid order enemy")
		if skills.get("rows", []) != [2, 4]: errors.append(id + ": orders must use visible side entrances")

func chapter_waves(id: String) -> Array[Resource]:
	if chapters.has(id): return chapters[id].waves
	var empty: Array[Resource] = []
	return empty

func scene_chapters(id: String) -> Array[String]:
	if scenes.has(id): return scenes[id].chapter_ids.duplicate()
	return []

func scene_wave_count(id: String) -> int:
	var total: int = 0
	for chapter_id: String in scene_chapters(id): total += chapter_waves(chapter_id).size()
	return total

func chapter_offset(scene_id: String, chapter_id: String) -> int:
	var offset: int = 0
	for id: String in scene_chapters(scene_id):
		if id == chapter_id: return offset
		offset += chapter_waves(id).size()
	return -1

func scene_error(id: String) -> String:
	if not scenes.has(id): return "未知场景，请选择场景从第一大关开始"
	if not scenes[id].available: return "这个场景正在制作中"
	for chapter_id: String in scene_chapters(id):
		if not chapters.has(chapter_id) or not chapters[chapter_id].available: return "这个场景尚未完成"
	return ""
