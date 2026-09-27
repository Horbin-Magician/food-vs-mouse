class_name CombatController
extends RefCounted

signal damage_resolved(unit: Dictionary, actual: float, is_food: bool, direct: bool)
signal acted(uid: int)
signal spawned(unit: Dictionary)
signal enemy_hurt(unit: Dictionary)
signal enemy_fallen(unit: Dictionary)
signal food_hurt(unit: Dictionary)
signal food_fallen(unit: Dictionary)
signal skill_used(effect_id: String, source: Dictionary, targets: Array)
signal heat_collected(pickup: Dictionary)

signal unit_died(food_id: String)
signal enemy_leaked(damage: int)
signal enemy_killed(enemy_id: String)

var state: RunState
var data: Catalog
var board: BoardController
var recipes: RecipeSystem
var rng: RandomNumberGenerator
var warning_summons: Array[Dictionary] = []
var current_wave: Resource
var enemies: Array = []
# uid -> live enemy; identity lookup instead of content-comparing Array.has().
var alive: Dictionary = {}
var projectiles: Array = []
var heat_pickups: Array[Dictionary] = []
var inspiration_pickups: Array[Dictionary] = []
var inspiration_collected: int = 0
var _inspiration_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var abilities: EnemyAbilities

func _init(s: RunState, c: Catalog, b: BoardController, r: RecipeSystem, random: RandomNumberGenerator) -> void:
	state = s
	data = c
	board = b
	recipes = r
	rng = random
	abilities = EnemyAbilities.new(self)
	reset_inspiration_rng()

func reset_inspiration_rng() -> void:
	# Replaying a wave rebuilds drops without consuming the gameplay random stream.
	_inspiration_rng.seed = ("inspiration:%d:%d" % [state.seed_value, state.global_wave()]).hash()

func begin_wave() -> void:
	inspiration_pickups.clear()
	inspiration_collected = 0
	reset_inspiration_rng()

func clear(preserve_heat: bool = false) -> void:
	abilities.clear()
	warning_summons.clear()
	enemies.clear()
	alive.clear()
	projectiles.clear()
	if not preserve_heat: heat_pickups.clear()
	inspiration_pickups.clear()
	inspiration_collected = 0
	reset_inspiration_rng()
	for unit: Dictionary in state.units:
		unit.timer = 0.0
		unit.attacks = 0
		unit.flour = 0.0

func spawn(id: String, row: int, wave: Resource) -> Dictionary:
	if not data.enemies.has(id) or row < 0 or row >= RunState.ROWS or wave == null: return {}
	current_wave = wave
	var definition: EnemyDef = data.enemies[id]
	var stats: Dictionary = definition.stats
	var hp_scale: float = 1.0 if definition.rank == "boss" else float(wave.stats.get("hp_scale", 1.0))
	var damage_scale: float = 1.0 if definition.rank == "boss" else float(wave.stats.get("damage_scale", 1.0))
	var difficulty: DifficultyDef = data.difficulties[state.difficulty]
	hp_scale *= difficulty.hp_multiplier
	damage_scale *= difficulty.damage_multiplier
	var enemy: Dictionary = {"uid": state.uid(), "id": id, "wave":wave, "rank":definition.rank, "art_id":definition.art_id, "hp_scale":hp_scale, "damage_scale":damage_scale, "row": row, "x": float(RunState.BOARD_WIDTH + 52), "hp": stats.hp * hp_scale, "max_hp": stats.hp * hp_scale, "dps": stats.dps * damage_scale, "summon": 0.0, "rage": false, "slow": 0.0, "slow_time": 0.0, "burn_time": 0.0, "burn_tick": 0.0, "armor": stats.get("armor_hits", 0), "timer": 0.0, "flash": 0.0}
	enemies.append(enemy)
	alive[enemy.uid] = enemy
	abilities.setup(enemy)
	spawned.emit(enemy)
	return enemy

func add_heat(amount: float) -> void:
	state.metrics.overflow += maxf(0.0, state.heat + amount - data.rules.heat_cap)
	state.heat = minf(data.rules.heat_cap, state.heat + amount)

func produce_heat(unit: Dictionary) -> void:
	skill_used.emit("produce", unit, [])
	var amount: float = data.rules.production * state.production_multiplier(unit.id, data) + recipes.value("caramel", "heat")
	for pickup: Dictionary in heat_pickups:
		if pickup.source_uid == unit.uid and pickup.flight < 0.0:
			pickup.amount += amount
			return
	heat_pickups.append({"uid": state.uid(), "source_uid": unit.uid, "row": unit.row, "col": unit.col, "amount": amount, "age": 0.0, "flight": -1.0})

func collect_heat(uid: int) -> bool:
	if state.phase != "battle": return false
	for pickup: Dictionary in heat_pickups:
		if pickup.uid == uid and pickup.flight < 0.0:
			pickup.flight = 0.0
			heat_collected.emit(pickup)
			return true
	return false

func advance_heat_pickups(delta: float) -> void:
	for pickup: Dictionary in heat_pickups.duplicate():
		if pickup.flight < 0.0:
			pickup.age += delta
		else:
			pickup.flight += delta
			if pickup.flight + 0.000001 >= data.rules.heat_flight_duration:
				add_heat(pickup.amount)
				heat_pickups.erase(pickup)

func drop_inspiration(enemy: Dictionary) -> void:
	if not state.rewards_enabled: return
	var difficulty: DifficultyDef = data.difficulties[state.difficulty]
	var chance: float = difficulty.inspiration_drop_chance
	var roll: float = _inspiration_rng.randf()
	if chance <= 0.0 or (chance < 1.0 and roll >= chance): return
	inspiration_pickups.append({"uid": state.uid(), "row": enemy.row, "x": enemy.x, "amount": data.progression.inspiration_drop_amount, "age": 0.0, "flight": -1.0})

func inspiration_pickup(uid: int) -> Dictionary:
	for pickup: Dictionary in inspiration_pickups:
		if pickup.uid == uid and pickup.flight < 0.0: return pickup
	return {}

func collect_inspiration(uid: int) -> bool:
	if state.phase != "battle": return false
	var pickup: Dictionary = inspiration_pickup(uid)
	if pickup.is_empty(): return false
	pickup.flight = 0.0
	inspiration_collected += pickup.amount
	return true

func advance_inspiration_pickups(delta: float) -> void:
	for pickup: Dictionary in inspiration_pickups.duplicate():
		if pickup.flight < 0.0:
			pickup.age += delta
		else:
			pickup.flight += delta
			if pickup.flight + 0.000001 >= data.progression.inspiration_flight_duration:
				inspiration_pickups.erase(pickup)

func step(delta: float) -> void:
	if delta <= 0 or not is_finite(delta): return
	# A single fixed-rate frame is already one slice; skip the per-enemy content scan.
	if delta > 1.0 / 60.0 and abilities.has_active_content():
		var remaining: float = delta
		while remaining > 0.000001:
			var slice: float = minf(remaining, 1.0 / 60.0)
			_step(slice)
			remaining -= slice
	else:
		_step(delta)

func _step(delta: float) -> void:
	advance_summons(delta)
	abilities.prepare(delta)
	add_heat(data.rules.heat_rate * delta)
	advance_heat_pickups(delta)
	advance_inspiration_pickups(delta)
	for id: String in state.cooldowns:
		state.cooldowns[id] = maxf(0.0, state.cooldowns[id] - delta)
	# Food never moves or dies inside this loop, so adjacency can use a snapshot.
	recipes.index_units()
	for unit: Dictionary in state.units.duplicate():
		unit.flash = maxf(0.0, unit.flash - delta)
		unit.flour = maxf(0.0,unit.flour - delta)
		var stats: Dictionary = data.foods[unit.id].stats
		if stats.kind == "wall": continue
		unit.timer += delta
		var interval: float = recipes.interval(unit)
		if unit.timer + 0.000001 < interval: continue
		if stats.kind == "producer":
			unit.timer -= stats.interval
			acted.emit(unit.uid)
			produce_heat(unit)
			continue
		var target: Dictionary = nearest(unit.row, unit.col * 96.0 + 48.0, recipes.reach(unit.id) * 96.0)
		if target.is_empty():
			unit.timer = interval
			continue
		unit.timer = 0.0
		unit.attacks += 1
		acted.emit(unit.uid)
		if stats.kind == "melee":
			skill_used.emit("melee", unit, [target])
			damage_enemy(target,recipes.damage(unit),unit.id)
		else:
			projectiles.append({"row": unit.row, "x": unit.col * 96.0 + 48.0, "damage": recipes.damage(unit), "source": unit.id, "radius": recipes.radius(unit) * 96.0, "remaining": stats.get("pierce",1), "hit": []})
	recipes.clear_index()
	for projectile: Dictionary in projectiles.duplicate():
		var distance: float = data.rules.projectile_speed * delta
		var targets: Array = []
		for e: Dictionary in enemies:
			if e.row == projectile.row and e.x >= projectile.x - 15.0 and e.x <= projectile.x + distance + 15.0 and e.uid not in projectile.hit:
				targets.append(e)
		targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.x < b.x)
		projectile.x += distance
		for target: Dictionary in targets:
			if not is_alive(target): continue
			projectile.hit.append(target.uid)
			hit(projectile,target)
			projectile.remaining -= 1
			if projectile.remaining <= 0: break
		if projectile.remaining <= 0 or projectile.x > RunState.BOARD_WIDTH + 132.0: projectiles.erase(projectile)
	var drummers: Array = enemies.filter(func(e: Dictionary) -> bool: return e.id == "drummer")
	for enemy: Dictionary in enemies.duplicate():
		enemy.flash = maxf(0.0, enemy.flash - delta)
		enemy.slow_time = maxf(0.0,enemy.slow_time-delta)
		if enemy.slow_time <= 0: enemy.slow = 0.0
		if enemy.burn_time > 0:
			enemy.burn_time = maxf(0.0,enemy.burn_time-delta)
			enemy.burn_tick += delta
			if enemy.burn_tick + 0.000001 >= data.rules.burn_tick:
				enemy.burn_tick -= data.rules.burn_tick
				damage_enemy(enemy,recipes.value("burn","damage"),"pepper",false)
				if not is_alive(enemy): continue
	# Resolve every enemy's incoming damage before any due ability or ground burst.
	var acting: Array = enemies.duplicate()
	acting.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.uid < b.uid)
	for enemy: Dictionary in acting:
		if not is_alive(enemy): continue
		abilities.tick(enemy, delta)
		if enemy.id == "boss":
			enemy.summon += delta
			var summon_interval: float = boss_interval(enemy.rage, enemy)
			if enemy.summon + 0.000001 >= summon_interval:
				enemy.summon = maxf(0.0, enemy.summon - summon_interval)
				request_summons(boss_configuration(enemy).get("rage_id" if enemy.rage else "normal_id", "gray"), enemy)
		# One unit scan serves both the contact test and the movement clamp.
		var ahead: Dictionary = blocker_ahead(enemy)
		var blocker: Dictionary = blocker_in_contact(enemy, ahead)
		if not blocker.is_empty(): abilities.on_blocked(enemy, blocker)
		if blocker.is_empty():
			enemy.timer = 0.0
			if abilities.can_move(enemy):
				var next_x: float = enemy.x - abilities.movement_speed(enemy) * movement_multiplier(enemy, drummers) * (1.0-enemy.slow) * delta
				if not ahead.is_empty(): next_x = maxf(next_x, ahead.col * 96.0 + 96.0)
				# Moving left cannot uncover a nearer unit, so the earlier scan stays valid.
				var moved_back: bool = next_x > enemy.x
				enemy.x = next_x
				var reached: Dictionary = blocker_for(enemy) if moved_back else blocker_in_contact(enemy, ahead)
				if not reached.is_empty(): abilities.on_blocked(enemy, reached)
		elif abilities.can_attack(enemy):
			enemy.timer += delta
			if enemy.timer + 0.000001 >= 1.0:
				enemy.timer = maxf(0.0, enemy.timer - 1.0)
				acted.emit(enemy.uid)
				damage_unit(blocker, enemy.dps)
				abilities.after_attack(enemy, blocker, enemy.dps)
		else:
			enemy.timer = 0.0
		if enemy.x < 0.0:
			abilities.removed(enemy, true)
			enemies.erase(enemy)
			alive.erase(enemy.uid)
			var loss: int = data.enemies[enemy.id].stats.leak
			state.pantry = maxi(0, state.pantry - loss)
			state.leaks += loss
			state.metrics.leaks += loss
			enemy_leaked.emit(loss)
	abilities.advance_ground()
	abilities.finish_step()

func blocker_ahead(enemy: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for unit: Dictionary in state.units:
		if unit.row == enemy.row and unit.col * 96.0 + 48.0 <= enemy.x:
			if result.is_empty() or unit.col > result.col: result = unit
	return result

func blocker_for(enemy: Dictionary) -> Dictionary:
	return blocker_in_contact(enemy, blocker_ahead(enemy))

func blocker_in_contact(enemy: Dictionary, ahead: Dictionary) -> Dictionary:
	return ahead if not ahead.is_empty() and enemy.x - (ahead.col * 96.0 + 48.0) <= 48.000001 else {}

func is_alive(enemy: Dictionary) -> bool:
	return is_same(alive.get(enemy.get("uid", -1)), enemy)

func nearest(row: int, x: float, reach: float) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy.row == row and enemy.x >= x and enemy.x - x <= reach:
			if result.is_empty() or enemy.x < result.x: result = enemy
	return result

func damage_enemy(enemy: Dictionary, amount: float, source: String, direct: bool = true) -> void:
	if not is_alive(enemy) or enemy.hp <= 0.0 or amount <= 0.0 or not is_finite(amount): return
	if direct and source == "pepper" and enemy.slow_time > 0:
		amount *= recipes.value("cold_spice","multiplier",1.0)
		if recipes.has("cold_spice"): skill_used.emit("cold_spice", enemy, [])
	amount *= float(enemy.get("exposed", 1.0))
	var previous_armor: int = int(enemy.armor)
	var previous_shield: float = float(enemy.get("shield", 0.0))
	if direct and enemy.armor > 0:
		amount = maxf(1.0, amount - data.enemies[enemy.id].stats.get("armor", 0))
		enemy.armor -= 1
	var absorbed: float = minf(float(enemy.get("shield", 0.0)), amount)
	enemy.shield = maxf(0.0, float(enemy.get("shield", 0.0)) - absorbed)
	amount -= absorbed
	var actual: float = absorbed + minf(enemy.hp, amount)
	enemy.hp -= amount
	damage_resolved.emit(enemy, actual, false, direct)
	enemy.flash = 0.15
	if enemy.hp > 0: enemy_hurt.emit(enemy)
	state.metrics.damage[source] = state.metrics.damage.get(source, 0.0) + actual
	if enemy.id == "boss" and not enemy.rage and enemy.hp > 0 and enemy.hp < enemy.max_hp * data.rules.boss_rage_threshold:
		enemy.rage = true
		enemy.summon *= boss_interval(true, enemy) / boss_interval(false, enemy)
		skill_used.emit("rage", enemy, [])
		request_summons(boss_configuration(enemy).get("burst_id", "lid"), enemy)
	if enemy.hp > 0: abilities.after_damage(enemy, previous_shield, previous_armor)
	if enemy.hp <= 0:
		if enemy.id == "flour":
			var cloud: Dictionary = enemy.duplicate()
			cloud["radius"] = data.rules.flour_radius
			skill_used.emit("flour", cloud, [])
			for unit: Dictionary in state.units:
				if unit.row == enemy.row and absf(unit.col * 96.0 + 48.0-enemy.x) <= data.rules.flour_radius:
					unit.flour = data.rules.flour_duration
		enemy_fallen.emit(enemy)
		abilities.removed(enemy)
		enemies.erase(enemy)
		alive.erase(enemy.uid)
		warning_summons = warning_summons.filter(func(warning: Dictionary) -> bool: return warning.caster != enemy.uid)
		drop_inspiration(enemy)
		state.metrics.kills += 1
		enemy_killed.emit(enemy.id)
		if recipes.has("recycle") and state.metrics.kills % int(recipes.value("recycle","every")) == 0:
			add_heat(recipes.value("recycle","heat"))
			skill_used.emit("recycle", enemy, [])

func damage_unit(unit: Dictionary, amount: float, direct: bool = true) -> void:
	if not state.units.has(unit) or amount <= 0.0 or not is_finite(amount): return
	if direct and unit.id == "toast": amount = maxf(1.0,amount-recipes.value("crust","armor"))
	var actual: float = minf(unit.hp, amount)
	unit.hp -= amount
	damage_resolved.emit(unit, actual, true, direct)
	unit.flash = 0.15
	if unit.hp > 0: food_hurt.emit(unit)
	if unit.hp <= 0:
		food_fallen.emit(unit)
		state.units.erase(unit)
		state.metrics.deaths += 1
		unit_died.emit(unit.id)

func hit(projectile: Dictionary, target: Dictionary) -> void:
	if not is_alive(target): return
	var affected: Array = [target]
	if projectile.radius > 0:
		affected = enemies.filter(func(e: Dictionary) -> bool: return e.row == target.row and absf(e.x-target.x) <= projectile.radius)
		var impact: Dictionary = target.duplicate()
		impact["radius"] = projectile.radius
		skill_used.emit("steam" if projectile.source == "bun" else "popcorn", impact, [])
	for enemy: Dictionary in affected:
		var multiplier: float = recipes.value("burst","multiplier",1.0) if projectile.source == "popcorn" and enemy.uid == target.uid else 1.0
		damage_enemy(enemy,projectile.damage * multiplier,projectile.source)
		if not is_alive(enemy): continue
		if projectile.source == "tea":
			enemy.slow = maxf(enemy.slow,recipes.value("ice","slow",data.foods.tea.stats.slow))
			enemy.slow_time = data.foods.tea.stats.slow_duration
		if projectile.source == "pepper" and recipes.has("burn"):
			if enemy.burn_time <= 0: enemy.burn_tick = 0.0
			enemy.burn_time = recipes.value("burn","duration")

func summon_pair(id: String, caster: Dictionary = {}) -> void:
	if not data.enemies.has(id) or current_wave == null: return
	if not caster.is_empty() and not is_alive(caster): return
	var first: int = rng.randi_range(0,RunState.ROWS-1)
	var second: int = rng.randi_range(0,RunState.ROWS-2)
	if second >= first: second += 1
	spawn(id,first,caster.get("wave", current_wave))
	var first_unit: Dictionary = enemies[-1]
	spawn(id,second,caster.get("wave", current_wave))
	if not caster.is_empty():
		skill_used.emit("reinforce" if id == "lid" else "summon", caster, [first_unit, enemies[-1]])

func is_drummer_boosted(enemy: Dictionary, sources: Array) -> bool:
	for other: Dictionary in sources:
		if other.hp > 0 and other.x >= 0 and other.uid != enemy.uid and other.id == "drummer" and other.row == enemy.row and absf(other.x-enemy.x) <= data.rules.drummer_radius:
			return true
	return false

func movement_multiplier(enemy: Dictionary, sources: Array) -> float:
	var result: float = 1.0 + (data.rules.boss_rage_speed if enemy.rage else 0.0)
	return result * (1.0 + data.rules.drummer_speed) if is_drummer_boosted(enemy, sources) else result

func boss_configuration(caster: Dictionary = {}) -> Dictionary:
	var wave: Resource = caster.get("wave", current_wave)
	return wave.stats.get("boss", {}) if wave != null else {}

func boss_interval(rage: bool, caster: Dictionary = {}) -> float:
	return boss_configuration(caster).get("rage_interval" if rage else "interval", data.rules.boss_rage_summon_interval if rage else data.rules.boss_summon_interval)

func enemy_title(id: String) -> String:
	if not data.enemies.has(id): return "未知老鼠"
	return boss_configuration().get("title", data.enemies[id].title) if id == "boss" else data.enemies[id].title

func request_summons(id: String, caster: Dictionary) -> void:
	if not data.enemies.has(id) or not is_alive(caster) or caster.hp <= 0: return
	var configuration: Dictionary = boss_configuration(caster)
	if configuration.is_empty():
		summon_pair(id, caster)
		return
	warning_summons.append({"caster":caster.uid, "id":id, "rows":configuration.rows.duplicate(), "remaining":float(configuration.warning_seconds)})

func advance_summons(delta: float) -> void:
	for warning: Dictionary in warning_summons.duplicate():
		var casters: Array = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.uid == warning.caster)
		if casters.is_empty():
			warning_summons.erase(warning)
			continue
		warning.remaining -= delta
		if warning.remaining > 0.000001: continue
		warning_summons.erase(warning)
		var targets: Array = []
		for row: int in warning.rows:
			spawn(warning.id, row, casters[0].get("wave", current_wave))
			targets.append(enemies[-1])
		skill_used.emit("reinforce" if warning.id == "lid" else "summon", casters[0], targets)
