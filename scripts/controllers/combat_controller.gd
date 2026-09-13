class_name CombatController
extends RefCounted

signal acted(uid: int)
signal spawned(unit: Dictionary)

signal unit_died(food_id: String)
signal enemy_leaked(damage: int)
signal enemy_killed(enemy_id: String)

var state: RunState
var data: Catalog
var board: BoardController
var recipes: RecipeSystem
var rng: RandomNumberGenerator
var current_wave: Resource
var enemies: Array = []
var projectiles: Array = []

func _init(s: RunState, c: Catalog, b: BoardController, r: RecipeSystem, random: RandomNumberGenerator) -> void:
	state = s
	data = c
	board = b
	recipes = r
	rng = random

func clear() -> void:
	enemies.clear()
	projectiles.clear()
	for unit: Dictionary in state.units:
		unit.timer = 0.0
		unit.attacks = 0
		unit.flour = 0.0

func spawn(id: String, row: int, wave: Resource) -> void:
	current_wave = wave
	var stats: Dictionary = data.enemies[id].stats
	var hp_scale: float = 1.0 if id == "boss" else wave.stats.hp_scale
	var damage_scale: float = 1.0 if id == "boss" else wave.stats.damage_scale
	enemies.append({"uid": state.uid(), "id": id, "row": row, "x": 820.0, "hp": stats.hp * hp_scale, "max_hp": stats.hp * hp_scale, "dps": stats.dps * damage_scale, "summon": 0.0, "rage": false, "slow": 0.0, "slow_time": 0.0, "burn_time": 0.0, "burn_tick": 0.0, "armor": stats.get("armor_hits", 0), "timer": 0.0, "flash": 0.0})

	spawned.emit(enemies[-1])

func add_heat(amount: float) -> void:
	state.metrics.overflow += maxf(0.0, state.heat + amount - data.rules.heat_cap)
	state.heat = minf(data.rules.heat_cap, state.heat + amount)

func step(delta: float) -> void:
	add_heat(data.rules.heat_rate * delta)
	for id: String in state.cooldowns:
		state.cooldowns[id] = maxf(0.0, state.cooldowns[id] - delta)
	for unit: Dictionary in state.units.duplicate():
		unit.flash = maxf(0.0, unit.flash - delta)
		unit.flour = maxf(0.0,unit.flour - delta)
		var stats: Dictionary = data.foods[unit.id].stats
		if stats.kind == "wall": continue
		unit.timer += delta
		var interval: float = recipes.interval(unit)
		if unit.timer < interval: continue
		if stats.kind == "producer":
			unit.timer -= stats.interval
			acted.emit(unit.uid)
			add_heat(data.rules.production * data.rules.star_production[state.star(unit.id) - 1] + recipes.value("caramel","heat"))
			continue
		var target: Dictionary = nearest(unit.row, unit.col * 96.0 + 48.0, recipes.reach(unit.id) * 96.0)
		if target.is_empty():
			unit.timer = interval
			continue
		unit.timer = 0.0
		unit.attacks += 1
		acted.emit(unit.uid)
		if stats.kind == "melee":
			damage_enemy(target,recipes.damage(unit),unit.id)
		else:
			projectiles.append({"row": unit.row, "x": unit.col * 96.0 + 48.0, "damage": recipes.damage(unit), "source": unit.id, "radius": recipes.radius(unit) * 96.0, "remaining": stats.get("pierce",1), "hit": []})
	for projectile: Dictionary in projectiles.duplicate():
		var distance: float = data.rules.projectile_speed * delta
		var targets: Array = enemies.filter(func(e: Dictionary) -> bool: return e.row == projectile.row and e.x >= projectile.x - 15.0 and e.x <= projectile.x + distance + 15.0 and e.uid not in projectile.hit)
		targets.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.x < b.x)
		projectile.x += distance
		for target: Dictionary in targets:
			if not enemies.has(target): continue
			projectile.hit.append(target.uid)
			hit(projectile,target)
			projectile.remaining -= 1
			if projectile.remaining <= 0: break
		if projectile.remaining <= 0 or projectile.x > 900.0: projectiles.erase(projectile)
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
			if not enemies.has(enemy): continue
		if enemy.id == "boss":
			enemy.summon += delta
			if enemy.summon >= data.rules.boss_summon_interval:
				enemy.summon -= data.rules.boss_summon_interval
				summon_pair("gray")
		var blocker: Dictionary = {}
		for unit: Dictionary in state.units:
			var x: float = unit.col * 96.0 + 48.0
			if unit.row == enemy.row and x <= enemy.x and enemy.x - x <= 48.0:
				if blocker.is_empty() or unit.col > blocker.col: blocker = unit
		if blocker.is_empty():
			enemy.timer = 0.0
			enemy.x -= data.enemies[enemy.id].stats.speed * movement_multiplier(enemy, drummers) * (1.0-enemy.slow) * delta
		else:
			enemy.timer += delta
			if enemy.timer >= 1.0:
				enemy.timer -= 1.0
				acted.emit(enemy.uid)
				damage_unit(blocker, enemy.dps)
		if enemy.x < 0.0:
			enemies.erase(enemy)
			var loss: int = data.enemies[enemy.id].stats.leak
			state.pantry = maxi(0, state.pantry - loss)
			state.leaks += loss
			state.metrics.leaks += loss
			enemy_leaked.emit(loss)

func nearest(row: int, x: float, reach: float) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy.row == row and enemy.x >= x and enemy.x - x <= reach:
			if result.is_empty() or enemy.x < result.x: result = enemy
	return result

func damage_enemy(enemy: Dictionary, amount: float, source: String, direct: bool = true) -> void:
	if not enemies.has(enemy): return
	if direct and source == "pepper" and enemy.slow_time > 0: amount *= recipes.value("cold_spice","multiplier",1.0)
	if direct and enemy.armor > 0:
		amount = maxf(1.0, amount - data.enemies[enemy.id].stats.get("armor", 0))
		enemy.armor -= 1
	var actual: float = minf(enemy.hp, amount)
	enemy.hp -= amount
	enemy.flash = 0.15
	state.metrics.damage[source] = state.metrics.damage.get(source, 0.0) + actual
	if enemy.id == "boss" and not enemy.rage and enemy.hp > 0 and enemy.hp < enemy.max_hp * data.rules.boss_rage_threshold:
		enemy.rage = true
		summon_pair("lid")
	if enemy.hp <= 0:
		if enemy.id == "flour":
			for unit: Dictionary in state.units:
				if unit.row == enemy.row and absf(unit.col * 96.0 + 48.0-enemy.x) <= data.rules.flour_radius:
					unit.flour = data.rules.flour_duration
		enemies.erase(enemy)
		state.metrics.kills += 1
		enemy_killed.emit(enemy.id)
		if recipes.has("recycle") and state.metrics.kills % int(recipes.value("recycle","every")) == 0:
			add_heat(recipes.value("recycle","heat"))

func damage_unit(unit: Dictionary, amount: float) -> void:
	if not state.units.has(unit): return
	if unit.id == "toast": amount = maxf(1.0,amount-recipes.value("crust","armor"))
	unit.hp -= amount
	unit.flash = 0.15
	if unit.hp <= 0:
		state.units.erase(unit)
		state.metrics.deaths += 1
		unit_died.emit(unit.id)

func hit(projectile: Dictionary, target: Dictionary) -> void:
	var affected: Array = [target]
	if projectile.radius > 0:
		affected = enemies.filter(func(e: Dictionary) -> bool: return e.row == target.row and absf(e.x-target.x) <= projectile.radius)
	for enemy: Dictionary in affected:
		var multiplier: float = recipes.value("burst","multiplier",1.0) if projectile.source == "popcorn" and enemy.uid == target.uid else 1.0
		damage_enemy(enemy,projectile.damage * multiplier,projectile.source)
		if not enemies.has(enemy): continue
		if projectile.source == "tea":
			enemy.slow = maxf(enemy.slow,recipes.value("ice","slow",data.foods.tea.stats.slow))
			enemy.slow_time = data.foods.tea.stats.slow_duration
		if projectile.source == "pepper" and recipes.has("burn"):
			if enemy.burn_time <= 0: enemy.burn_tick = 0.0
			enemy.burn_time = recipes.value("burn","duration")

func summon_pair(id: String) -> void:
	var first: int = rng.randi_range(0,4)
	var second: int = rng.randi_range(0,3)
	if second >= first: second += 1
	spawn(id,first,current_wave)
	spawn(id,second,current_wave)

func movement_multiplier(enemy: Dictionary, sources: Array) -> float:
	var result: float = 1.0 + (data.rules.boss_rage_speed if enemy.rage else 0.0)
	for other: Dictionary in sources:
		if other.hp > 0 and other.x >= 0 and other.uid != enemy.uid and other.id == "drummer" and other.row == enemy.row and absf(other.x-enemy.x) <= data.rules.drummer_radius:
			return result * (1.0 + data.rules.drummer_speed)
	return result
