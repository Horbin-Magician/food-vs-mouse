class_name CombatController
extends RefCounted

signal unit_died(food_id: String)
signal enemy_leaked(damage: int)
signal enemy_killed(enemy_id: String)

var state: RunState
var data: Catalog
var board: BoardController
var enemies: Array = []
var projectiles: Array = []

func _init(s: RunState, c: Catalog, b: BoardController) -> void:
	state = s
	data = c
	board = b

func clear() -> void:
	enemies.clear()
	projectiles.clear()
	for unit: Dictionary in state.units:
		unit.timer = 0.0
		unit.attacks = 0
		unit.flour = 0.0

func spawn(id: String, row: int, wave: Resource) -> void:
	var stats: Dictionary = data.enemies[id].stats
	enemies.append({"uid": state.uid(), "id": id, "row": row, "x": 820.0, "hp": stats.hp * wave.stats.hp_scale, "max_hp": stats.hp * wave.stats.hp_scale, "dps": stats.dps * wave.stats.damage_scale, "timer": 0.0, "flash": 0.0})

func add_heat(amount: float) -> void:
	state.metrics.overflow += maxf(0.0, state.heat + amount - data.rules.heat_cap)
	state.heat = minf(data.rules.heat_cap, state.heat + amount)

func step(delta: float) -> void:
	add_heat(data.rules.heat_rate * delta)
	for id: String in state.cooldowns:
		state.cooldowns[id] = maxf(0.0, state.cooldowns[id] - delta)
	for unit: Dictionary in state.units.duplicate():
		unit.flash = maxf(0.0, unit.flash - delta)
		var stats: Dictionary = data.foods[unit.id].stats
		if stats.kind == "wall": continue
		unit.timer += delta
		if unit.timer < stats.interval: continue
		if stats.kind == "producer":
			unit.timer -= stats.interval
			add_heat(data.rules.production * data.rules.star_production[state.star(unit.id) - 1])
			continue
		var target: Dictionary = nearest(unit.row, unit.col * 96.0 + 48.0, stats.reach * 96.0)
		if target.is_empty():
			unit.timer = stats.interval
			continue
		unit.timer = 0.0
		unit.attacks += 1
		projectiles.append({"row": unit.row, "x": unit.col * 96.0 + 48.0, "damage": stats.damage * data.rules.star_hp[state.star(unit.id) - 1], "source": unit.id})
	for projectile: Dictionary in projectiles.duplicate():
		var distance: float = data.rules.projectile_speed * delta
		var target: Dictionary = nearest(projectile.row, projectile.x - 15.0, distance + 30.0)
		projectile.x += distance
		if not target.is_empty():
			damage_enemy(target, projectile.damage, projectile.source)
			projectiles.erase(projectile)
		elif projectile.x > 900.0: projectiles.erase(projectile)
	for enemy: Dictionary in enemies.duplicate():
		enemy.flash = maxf(0.0, enemy.flash - delta)
		var blocker: Dictionary = {}
		for unit: Dictionary in state.units:
			var x: float = unit.col * 96.0 + 48.0
			if unit.row == enemy.row and x <= enemy.x and enemy.x - x <= 48.0:
				if blocker.is_empty() or unit.col > blocker.col: blocker = unit
		if blocker.is_empty():
			enemy.timer = 0.0
			enemy.x -= data.enemies[enemy.id].stats.speed * delta
		else:
			enemy.timer += delta
			if enemy.timer >= 1.0:
				enemy.timer -= 1.0
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

func damage_enemy(enemy: Dictionary, amount: float, source: String) -> void:
	if not enemies.has(enemy): return
	var actual: float = minf(enemy.hp, amount)
	enemy.hp -= amount
	enemy.flash = 0.15
	state.metrics.damage[source] = state.metrics.damage.get(source, 0.0) + actual
	if enemy.hp <= 0:
		enemies.erase(enemy)
		state.metrics.kills += 1
		enemy_killed.emit(enemy.id)

func damage_unit(unit: Dictionary, amount: float) -> void:
	if not state.units.has(unit): return
	unit.hp -= amount
	unit.flash = 0.15
	if unit.hp <= 0:
		state.units.erase(unit)
		state.metrics.deaths += 1
		unit_died.emit(unit.id)
