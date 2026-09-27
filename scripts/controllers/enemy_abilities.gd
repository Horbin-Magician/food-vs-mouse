class_name EnemyAbilities
extends RefCounted

const EPSILON: float = 0.000001
var _owner: WeakRef
var combat: CombatController:
	get: return _owner.get_ref()
var clock: float = 0.0
var telegraphs: Array[Dictionary] = []
var ground_effects: Array[Dictionary] = []
var _next_effect: int = 1

func _init(owner: CombatController) -> void:
	_owner = weakref(owner)

func clear() -> void:
	clock = 0.0
	telegraphs.clear()
	ground_effects.clear()
	_next_effect = 1
	for unit: Dictionary in combat.state.units:
		unit.erase("proof_time")
		unit.erase("proof_penalty")

func behavior(enemy: Dictionary) -> String:
	return combat.data.enemies[enemy.id].behavior_id if combat.data.enemies.has(enemy.id) else "legacy"

func configuration(enemy: Dictionary) -> Dictionary:
	return combat.data.enemies[enemy.id].skills if combat.data.enemies.has(enemy.id) else {}

func setup(enemy: Dictionary) -> void:
	enemy.merge({"ability_phase":"normal", "ability_remaining":0.0, "ability_duration":0.0, "ability_title":"", "ability_state":"normal", "ability_elapsed":0.0, "ability_age":0.0, "ability_once":false, "ability_stage":false, "ability_pending_stage":false, "ability_target":-1, "ability_cells":[], "ability_rows":[], "dash_segment":0, "shield":0.0, "shield_max":0.0, "shield_time":0.0, "exposed":1.0, "exposed_time":0.0, "ration_stock":0, "ration_received":false, "order_index":-1, "order_remaining":3, "order_status":"idle", "order_time":0.0, "order_flags":[false,false,false], "order_members":[], "order_cooldown":0.0, "order_leaked":false, "order_sent":0, "shell_broken":false})
	var skills: Dictionary = configuration(enemy)
	if behavior(enemy) == "ration": enemy.ration_stock = int(skills.supplies)
	if behavior(enemy) == "ironpot":
		grant_shield(enemy, float(skills.shield) * enemy.hp_scale, -1.0, false)

func has_active_content() -> bool:
	if not ground_effects.is_empty(): return true
	for enemy: Dictionary in combat.enemies:
		if behavior(enemy) != "legacy": return true
	return false

func prepare(delta: float) -> void:
	clock += delta
	for enemy: Dictionary in combat.enemies:
		enemy.ability_age += delta
		if enemy.shield_time > 0:
			enemy.shield_time = maxf(0.0, enemy.shield_time - delta)
			if enemy.shield_time <= EPSILON:
				enemy.shield = 0.0
				enemy.shield_time = 0.0
		if enemy.exposed_time > 0:
			enemy.exposed_time = maxf(0.0, enemy.exposed_time - delta)
			if enemy.exposed_time <= EPSILON: enemy.exposed = 1.0
		enemy.order_cooldown = maxf(0.0, enemy.order_cooldown - delta)
	refresh_proof()

func tick(enemy: Dictionary, delta: float) -> void:
	if not combat.enemies.has(enemy) or enemy.hp <= 0: return
	var kind: String = behavior(enemy)
	if kind == "legacy": return
	var skills: Dictionary = configuration(enemy)
	if kind == "quartermaster" and enemy.ability_age + EPSILON >= float(skills.initial_delay):
		enemy.order_flags[0] = true
	if enemy.ability_state != "normal":
		enemy.ability_remaining = maxf(0.0, enemy.ability_remaining - delta)
		_sync_warning(enemy)
		if enemy.ability_remaining <= EPSILON: _finish_action(enemy)
		return
	if enemy.ability_pending_stage:
		enemy.ability_stage = true
		enemy.ability_pending_stage = false
	var blocker: Dictionary = combat.blocker_for(enemy)
	match kind:
		"skater":
			if blocker.is_empty(): enemy.ability_elapsed += delta
			if enemy.ability_elapsed + EPSILON >= float(skills.interval): _start_dash_warning(enemy)
		"scout":
			if not enemy.ability_once and enemy.x <= float(skills.entrance_max) and enemy.x >= float(skills.entrance_min) and blocker.is_empty():
				enemy.ability_once = true
				var candidates: Array[int] = []
				for row: int in [int(enemy.row) - 1, int(enemy.row) + 1]:
					if _clear_lane(enemy, row): candidates.append(row)
				if not candidates.is_empty():
					enemy.ability_rows = [enemy.row, candidates[combat.rng.randi_range(0, candidates.size() - 1)]]
					_begin(enemy, "switch", "windup", float(skills.windup), "探路折返", "switch")
		"breaker", "ironpot":
			if not blocker.is_empty(): enemy.ability_elapsed += delta
			var interval: float = float(skills.rage_interval) if kind == "ironpot" and enemy.ability_stage else float(skills.interval)
			if not blocker.is_empty() and enemy.ability_elapsed + EPSILON >= interval:
				enemy.ability_target = blocker.uid
				enemy.ability_cells = [{"row":blocker.row,"col":blocker.col}]
				_begin(enemy, "heavy", "windup", float(skills.windup), "落锅重砸" if kind == "ironpot" else "夹断", "heavy")
		"acid":
			enemy.ability_elapsed += delta
			if enemy.ability_elapsed + EPSILON >= float(skills.interval):
				var cells: Array = _acid_targets(enemy)
				if not cells.is_empty():
					enemy.ability_cells = cells
					_begin(enemy, "acid", "windup", float(skills.windup), "定点酸滴", "acid")
		"dough":
			if not enemy.ability_once and enemy.ability_age + EPSILON >= float(skills.interval):
				enemy.ability_once = true
				_begin(enemy, "dough", "windup", float(skills.windup), "一口醒面", "proof")
		"ration":
			enemy.ability_elapsed += delta
			if enemy.ration_stock > 0 and enemy.ability_elapsed + EPSILON >= float(skills.interval):
				var target: Dictionary = _ration_target(enemy)
				if not target.is_empty():
					enemy.ability_target = target.uid
					_begin(enemy, "ration", "windup", float(skills.windup), "配给护送", "ration")
		"windwhistle":
			enemy.ability_elapsed += delta
			var interval: float = float(skills.rage_interval) if enemy.ability_stage else float(skills.interval)
			if enemy.ability_elapsed + EPSILON >= interval: _start_dash_warning(enemy)
		"starter":
			enemy.ability_elapsed += delta
			if enemy.ability_elapsed + EPSILON >= float(skills.interval):
				var cells: Array = _proof_targets(enemy)
				if not cells.is_empty():
					enemy.ability_cells = cells
					_begin(enemy, "proof", "windup", float(skills.windup), "温床圈", "proof")
		"quartermaster":
			if enemy.order_status != "active" and enemy.order_cooldown <= EPSILON and enemy.exposed_time <= EPSILON:
				var next: int = int(enemy.order_sent)
				if next < skills.order_ids.size() and enemy.order_flags[next]:
					enemy.order_index = next
					enemy.order_status = "warning"
					enemy.ability_rows = skills.rows.duplicate()
					_begin(enemy, "order", "windup", float(skills.windup), "公示粮签", "order")
				elif next >= skills.order_ids.size(): enemy.order_status = "done"

func _begin(enemy: Dictionary, state: String, phase: String, duration: float, title: String, warning: String = "") -> void:
	_remove_warnings(enemy.uid)
	enemy.ability_state = state
	enemy.ability_phase = phase
	enemy.ability_remaining = duration
	enemy.ability_duration = duration
	enemy.ability_title = title
	enemy.timer = 0.0
	if warning.is_empty(): return
	var endpoint: float = enemy.x
	if warning == "dash":
		var skills: Dictionary = configuration(enemy)
		endpoint = maxf(0.0, enemy.x - float(skills.dash_speed) * float(skills.dash_duration) * int(skills.get("segments", 1)))
		var blocker: Dictionary = combat.blocker_ahead(enemy)
		if not blocker.is_empty(): endpoint = maxf(endpoint, blocker.col * 96.0 + 96.0)
	telegraphs.append({"uid":_effect_uid(),"source_uid":enemy.uid,"skill_id":warning,"kind":warning,"row":enemy.row,"x":enemy.x,"rows":enemy.ability_rows.duplicate(),"cells":enemy.ability_cells.duplicate(true),"target_uid":enemy.ability_target,"remaining":duration,"duration":duration,"end_x":endpoint})

func _normal(enemy: Dictionary, reset_elapsed: bool = true) -> void:
	_remove_warnings(enemy.uid)
	enemy.ability_state = "normal"
	enemy.ability_phase = "normal"
	enemy.ability_remaining = 0.0
	enemy.ability_duration = 0.0
	enemy.ability_title = ""
	enemy.ability_target = -1
	enemy.ability_cells.clear()
	enemy.ability_rows.clear()
	enemy.timer = 0.0
	if reset_elapsed: enemy.ability_elapsed = 0.0
	if enemy.ability_pending_stage:
		enemy.ability_stage = true
		enemy.ability_pending_stage = false

func _start_dash_warning(enemy: Dictionary) -> void:
	enemy.dash_segment = 0
	enemy.ability_rows = [enemy.row]
	_begin(enemy, "dash_warning", "windup", float(configuration(enemy).windup), "倒数哨" if behavior(enemy) == "windwhistle" else "借勺起跑", "dash")

func _finish_action(enemy: Dictionary) -> void:
	var skills: Dictionary = configuration(enemy)
	var kind: String = behavior(enemy)
	var state: String = enemy.ability_state
	_remove_warnings(enemy.uid)
	match state:
		"dash_warning", "dash_pause":
			enemy.dash_segment += 1
			_begin(enemy, "dash", "action", float(skills.dash_duration), "贴地快递" if kind == "windwhistle" else "冲刺")
			_event("dash", enemy, [])
			if not combat.blocker_for(enemy).is_empty(): on_blocked(enemy, combat.blocker_for(enemy))
		"dash":
			if enemy.dash_segment < int(skills.get("segments", 1)):
				_begin(enemy, "dash_pause", "recovery", float(skills.segment_pause), "接力停顿")
			else: _dash_recovery(enemy)
		"fatigue", "dash_recovery", "heavy_recovery", "shell_exposed", "proof_recovery", "order_failed":
			_normal(enemy)
		"switch":
			var row: int = int(enemy.ability_rows[1])
			if _clear_lane(enemy, row):
				var source: Dictionary = enemy.duplicate(true)
				enemy.row = row
				_event("switch", source, [enemy])
			_normal(enemy)
		"heavy":
			var target: Dictionary = _food_uid(enemy.ability_target)
			if not target.is_empty() and _touches(enemy, target):
				combat.damage_unit(target, float(skills.damage) * enemy.damage_scale)
				_event("heavy", enemy, [target])
			_begin(enemy, "heavy_recovery", "recovery", float(skills.recovery), "收力恢复")
		"acid":
			for cell: Dictionary in enemy.ability_cells:
				var target: Dictionary = combat.board.at(cell.row, cell.col)
				if not target.is_empty(): combat.damage_unit(target, float(skills.damage) * enemy.damage_scale)
				_add_acid(enemy, cell)
			_event("acid", enemy, enemy.ability_cells)
			_normal(enemy)
		"dough", "red_shield":
			grant_shield(enemy, float(skills.shield) * enemy.hp_scale, float(skills.shield_duration))
			_normal(enemy)
		"ration":
			var target: Dictionary = _enemy_uid(enemy.ability_target)
			if not target.is_empty() and _ration_eligible(enemy, target):
				if grant_shield(target, float(skills.shield) * enemy.hp_scale, float(skills.shield_duration)):
					target.ration_received = true
					enemy.ration_stock -= 1
					_event("ration", enemy, [target])
			_normal(enemy)
		"proof":
			for cell: Dictionary in enemy.ability_cells:
				ground_effects.append({"uid":_effect_uid(),"source_uid":enemy.uid,"skill_id":"proof","kind":"proof","row":cell.row,"col":cell.col,"remaining":float(skills.ground_duration),"duration":float(skills.ground_duration),"expires":clock + float(skills.ground_duration),"damage":float(skills.damage) * enemy.damage_scale,"penalty":float(skills.slow_penalty)})
			_event("proof", enemy, enemy.ability_cells)
			_begin(enemy, "proof_hold", "action", float(skills.ground_duration), "醒面结")
			refresh_proof()
		"proof_hold":
			_begin(enemy, "proof_recovery", "recovery", float(skills.recovery), "面种回缩")
			expose(enemy, float(skills.exposed), float(skills.recovery))
		"order":
			enemy.order_members = []
			var targets: Array = []
			for row: int in skills.rows:
				var child: Dictionary = combat.spawn(skills.order_ids[enemy.order_index], row, enemy.get("wave", combat.current_wave))
				if not child.is_empty():
					enemy.order_members.append(child.uid)
					targets.append(child)
			enemy.order_sent += 1
			enemy.order_remaining = maxi(0, skills.order_ids.size() - int(enemy.order_sent))
			enemy.order_status = "active"
			enemy.order_leaked = false
			enemy["order_deadline"] = clock + float(skills.observation)
			enemy.order_time = float(skills.observation)
			_event("order", enemy, targets)
			_normal(enemy)

func _dash_recovery(enemy: Dictionary) -> void:
	var skills: Dictionary = configuration(enemy)
	if behavior(enemy) == "windwhistle":
		var duration: float = float(skills.rage_recovery) if enemy.ability_stage else float(skills.recovery)
		_begin(enemy, "dash_recovery", "recovery", duration, "漏勺喘气")
		expose(enemy, float(skills.exposed), duration)
	else:
		_begin(enemy, "fatigue", "recovery", float(skills.recovery), "疲劳")

func on_blocked(enemy: Dictionary, blocker: Dictionary) -> void:
	if enemy.ability_state not in ["dash", "dash_pause"]: return
	if behavior(enemy) == "windwhistle" and enemy.ability_state == "dash":
		combat.damage_unit(blocker, float(configuration(enemy).damage) * enemy.damage_scale)
		_event("heavy", enemy, [blocker])
	_dash_recovery(enemy)

func can_move(enemy: Dictionary) -> bool:
	return enemy.ability_state in ["normal", "dash", "fatigue"]

func can_attack(enemy: Dictionary) -> bool:
	return enemy.ability_state == "normal" or enemy.ability_state == "fatigue" and behavior(enemy) == "skater"

func movement_speed(enemy: Dictionary) -> float:
	var skills: Dictionary = configuration(enemy)
	if enemy.ability_state == "dash": return float(skills.dash_speed)
	if enemy.ability_state == "fatigue": return float(skills.recovery_speed)
	if enemy.armor <= 0 and skills.has("unarmored_speed"): return float(skills.unarmored_speed)
	return float(combat.data.enemies[enemy.id].stats.speed)

func after_attack(enemy: Dictionary, primary: Dictionary, original: float) -> void:
	if behavior(enemy) != "skewer": return
	var skills: Dictionary = configuration(enemy)
	var second: Dictionary = {}
	for unit: Dictionary in combat.state.units:
		var distance: float = (int(primary.col) - int(unit.col)) * 96.0
		if unit.uid != primary.uid and unit.row == primary.row and distance > 0 and distance <= float(skills.splash_reach):
			if second.is_empty() or unit.col > second.col or unit.col == second.col and unit.uid < second.uid: second = unit
	if second.is_empty(): return
	combat.damage_unit(second, original * float(skills.splash_ratio))
	_event("skewer", enemy, [primary, second])

func after_damage(enemy: Dictionary, previous_shield: float, previous_armor: int) -> void:
	if not combat.enemies.has(enemy) or enemy.hp <= 0: return
	var kind: String = behavior(enemy)
	var skills: Dictionary = configuration(enemy)
	if previous_armor > 0 and enemy.armor <= 0 and skills.has("unarmored_speed"):
		_event("armor_break", enemy, [])
	if kind == "ironpot" and previous_shield > 0 and enemy.shield <= 0 and not enemy.shell_broken:
		_break_shell(enemy)
	if kind in ["windwhistle", "ironpot", "starter"] and not enemy.ability_stage and not enemy.ability_pending_stage and enemy.hp < enemy.max_hp * float(skills.threshold):
		enemy.ability_pending_stage = true
		if kind == "ironpot" and enemy.shield > 0 and not enemy.shell_broken:
			enemy.shield = 0.0
			enemy.shield_time = 0.0
			_break_shell(enemy)
		if enemy.ability_state == "normal":
			enemy.ability_stage = true
			enemy.ability_pending_stage = false
	if kind == "skewer" and skills.has("threshold") and not enemy.ability_once and enemy.hp < enemy.max_hp * float(skills.threshold):
		enemy.ability_once = true
		_begin(enemy, "red_shield", "windup", float(skills.windup), "红签护送", "proof")
	if kind == "quartermaster":
		for index: int in range(skills.thresholds.size()):
			if enemy.hp < enemy.max_hp * float(skills.thresholds[index]): enemy.order_flags[index + 1] = true

func _break_shell(enemy: Dictionary) -> void:
	var skills: Dictionary = configuration(enemy)
	enemy.shell_broken = true
	_begin(enemy, "shell_exposed", "recovery", float(skills.exposure_duration), "铆钉崩开")
	expose(enemy, float(skills.exposed), float(skills.exposure_duration))

func grant_shield(enemy: Dictionary, capacity: float, duration: float, emit_event: bool = true) -> bool:
	if enemy.hp <= 0 or capacity <= float(enemy.shield): return false
	enemy.shield = capacity
	enemy.shield_max = capacity
	enemy.shield_time = duration
	if emit_event: _event("shield", enemy, [enemy])
	return true

func expose(enemy: Dictionary, multiplier: float, duration: float) -> void:
	enemy.exposed = maxf(float(enemy.exposed), multiplier)
	enemy.exposed_time = maxf(float(enemy.exposed_time), duration)
	_event("exposed", enemy, [])

func removed(enemy: Dictionary, leaked: bool = false) -> void:
	_remove_warnings(enemy.uid)
	if enemy.rank == "boss":
		ground_effects = ground_effects.filter(func(effect: Dictionary) -> bool: return effect.source_uid != enemy.uid)
		refresh_proof()
	for caster: Dictionary in combat.enemies:
		if behavior(caster) == "quartermaster" and caster.order_status == "active" and enemy.uid in caster.order_members and leaked:
			caster.order_leaked = true

func advance_ground() -> void:
	for effect: Dictionary in ground_effects.duplicate():
		if not ground_effects.has(effect): continue
		if effect.kind == "proof":
			effect.remaining = maxf(0.0, float(effect.expires) - clock)
			if effect.remaining <= EPSILON:
				var caster: Dictionary = _enemy_uid(effect.source_uid)
				if not caster.is_empty():
					var target: Dictionary = combat.board.at(effect.row, effect.col)
					if not target.is_empty(): combat.damage_unit(target, float(effect.damage))
				ground_effects.erase(effect)
		else:
			while float(effect.next_tick) <= clock + EPSILON:
				var damage: float = 0.0
				for source: Dictionary in effect.sources:
					if float(source.expires) + EPSILON >= float(effect.next_tick): damage = maxf(damage, float(source.damage))
				var target: Dictionary = combat.board.at(effect.row, effect.col)
				if damage > 0 and not target.is_empty(): combat.damage_unit(target, damage, false)
				effect.next_tick += float(effect.tick_interval)
			effect.sources = effect.sources.filter(func(source: Dictionary) -> bool: return float(source.expires) > clock + EPSILON)
			effect.remaining = maxf(0.0, float(effect.expires) - clock)
			if effect.sources.is_empty(): ground_effects.erase(effect)
	refresh_proof()

func finish_step() -> void:
	for enemy: Dictionary in combat.enemies.duplicate():
		if behavior(enemy) != "quartermaster" or enemy.order_status != "active": continue
		enemy.order_time = maxf(0.0, float(enemy.order_deadline) - clock)
		var living: bool = false
		for uid: int in enemy.order_members:
			if not _enemy_uid(uid).is_empty(): living = true
		if enemy.order_leaked or not living:
			_resolve_order(enemy, false)
		elif enemy.order_time <= EPSILON:
			_resolve_order(enemy, true)

func _resolve_order(enemy: Dictionary, success: bool) -> void:
	var skills: Dictionary = configuration(enemy)
	enemy.order_status = "success" if success else "failed"
	enemy.order_time = 0.0
	enemy.order_cooldown = float(skills.order_gap)
	if success:
		grant_shield(enemy, float(skills.shield) * enemy.hp_scale, float(skills.shield_duration))
		_event("order_success", enemy, [])
	else:
		enemy.shield = 0.0
		enemy.shield_time = 0.0
		_begin(enemy, "order_failed", "recovery", float(skills.failure_duration), "断单重算")
		expose(enemy, float(skills.exposed), float(skills.failure_duration))
		_event("order_failed", enemy, [])

func refresh_proof() -> void:
	for unit: Dictionary in combat.state.units:
		unit["proof_time"] = 0.0
		unit["proof_penalty"] = 0.0
	for effect: Dictionary in ground_effects:
		if effect.kind != "proof" or float(effect.expires) < clock - EPSILON: continue
		var unit: Dictionary = combat.board.at(effect.row, effect.col)
		if not unit.is_empty():
			unit.proof_time = maxf(unit.proof_time, float(effect.expires) - clock)
			unit.proof_penalty = maxf(unit.proof_penalty, float(effect.penalty))

func _add_acid(enemy: Dictionary, cell: Dictionary) -> void:
	var skills: Dictionary = configuration(enemy)
	var source: Dictionary = {"source_uid":enemy.uid,"damage":float(skills.tick_damage) * enemy.damage_scale,"expires":clock + float(skills.ground_duration)}
	for effect: Dictionary in ground_effects:
		if effect.kind == "acid" and effect.row == cell.row and effect.col == cell.col:
			effect.sources.append(source)
			effect.expires = maxf(float(effect.expires), float(source.expires))
			effect.remaining = float(effect.expires) - clock
			return
	ground_effects.append({"uid":_effect_uid(),"source_uid":enemy.uid,"skill_id":"acid","kind":"acid","row":cell.row,"col":cell.col,"remaining":float(skills.ground_duration),"duration":float(skills.ground_duration),"expires":source.expires,"sources":[source],"next_tick":clock + float(skills.tick_interval),"tick_interval":float(skills.tick_interval)})

func _clear_lane(enemy: Dictionary, row: int) -> bool:
	if row < 0 or row >= RunState.ROWS: return false
	for unit: Dictionary in combat.state.units:
		if unit.row == row and absf(unit.col * 96.0 + 48.0 - enemy.x) <= float(configuration(enemy).clearance): return false
	return true

func _touches(enemy: Dictionary, target: Dictionary) -> bool:
	var x: float = target.col * 96.0 + 48.0
	return target.row == enemy.row and x <= enemy.x and enemy.x - x <= 48.0 + EPSILON

func _front_cell(enemy: Dictionary, row: int, reach: float) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in combat.state.units:
		var x: float = unit.col * 96.0 + 48.0
		if unit.row == row and x <= enemy.x and enemy.x - x <= reach:
			if result.is_empty() or unit.col > result.col: result = unit
	return {"row":result.row,"col":result.col} if not result.is_empty() else {}

func _acid_targets(enemy: Dictionary) -> Array:
	var skills: Dictionary = configuration(enemy)
	var cells: Array = []
	var own: Dictionary = _front_cell(enemy, enemy.row, float(skills.reach))
	if not own.is_empty(): cells.append(own)
	if int(skills.max_rows) > 1:
		var others: Array = []
		for row: int in [int(enemy.row) - 1, int(enemy.row) + 1]:
			if row < 0 or row >= RunState.ROWS: continue
			var cell: Dictionary = _front_cell(enemy, row, float(skills.reach))
			if not cell.is_empty(): others.append(cell)
		others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.col > b.col or a.col == b.col and a.row < b.row)
		if not others.is_empty(): cells.append(others[0])
	return cells

func _proof_targets(enemy: Dictionary) -> Array:
	var skills: Dictionary = configuration(enemy)
	var cells: Array = []
	for row: int in [int(enemy.row) - 1, int(enemy.row), int(enemy.row) + 1]:
		if row < 0 or row >= RunState.ROWS: continue
		var cell: Dictionary = _front_cell(enemy, row, float(skills.reach))
		if not cell.is_empty(): cells.append(cell)
	cells.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.col > b.col or a.col == b.col and a.row < b.row)
	return cells.slice(0, int(skills.rage_max_targets) if enemy.ability_stage else int(skills.max_targets))

func _ration_eligible(enemy: Dictionary, target: Dictionary) -> bool:
	return target.uid != enemy.uid and target.hp > 0 and target.rank != "boss" and behavior(target) != "ration" and target.row == enemy.row and target.x < enemy.x and enemy.x - target.x <= float(configuration(enemy).reach) and target.shield <= 0 and not target.ration_received

func _ration_target(enemy: Dictionary) -> Dictionary:
	var target: Dictionary = {}
	for other: Dictionary in combat.enemies:
		if _ration_eligible(enemy, other):
			if target.is_empty() or other.x < target.x or other.x == target.x and other.uid < target.uid: target = other
	return target

func _enemy_uid(uid: int) -> Dictionary:
	for enemy: Dictionary in combat.enemies:
		if enemy.uid == uid: return enemy
	return {}

func _food_uid(uid: int) -> Dictionary:
	for unit: Dictionary in combat.state.units:
		if unit.uid == uid: return unit
	return {}

func _sync_warning(enemy: Dictionary) -> void:
	for warning: Dictionary in telegraphs:
		if warning.source_uid == enemy.uid: warning.remaining = enemy.ability_remaining

func _remove_warnings(uid: int) -> void:
	telegraphs = telegraphs.filter(func(warning: Dictionary) -> bool: return warning.source_uid != uid)

func _effect_uid() -> int:
	var result: int = _next_effect
	_next_effect += 1
	return result

func _event(id: String, enemy: Dictionary, targets: Array) -> void:
	var source: Dictionary = enemy.duplicate(true)
	source["skill_id"] = id
	combat.skill_used.emit(id, source, targets)
