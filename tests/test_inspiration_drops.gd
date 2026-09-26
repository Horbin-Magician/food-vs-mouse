extends SceneTree

func combat_for(seed_value: int = 42, difficulty: String = "easy", chance: float = -1.0) -> CombatController:
	var data := Catalog.new()
	data.difficulties[difficulty] = data.difficulties[difficulty].duplicate(true)
	if chance >= 0.0: data.difficulties[difficulty].inspiration_drop_chance = chance
	var state := RunState.new()
	state.seed_value = seed_value
	state.difficulty = difficulty
	state.phase = "battle"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CombatController.new(state, data, BoardController.new(state, data), RecipeSystem.new(state, data), rng)

func spawn(combat: CombatController, id: String = "gray", row: int = 2, x: float = 400.0) -> Dictionary:
	combat.spawn(id, row, combat.data.waves[combat.state.wave - 1])
	var enemy: Dictionary = combat.enemies[-1]
	enemy.x = x
	return enemy

func drop_pattern(combat: CombatController, count: int = 2048) -> Array[bool]:
	var result: Array[bool] = []
	for index: int in range(count):
		var before: int = combat.inspiration_pickups.size()
		combat.damage_enemy(spawn(combat), 10000, "bun")
		result.append(combat.inspiration_pickups.size() > before)
	return result

func _init() -> void:
	var combat: CombatController = combat_for(42, "easy", 1.0)
	var enemy: Dictionary = spawn(combat)
	combat.damage_enemy(enemy, 1, "bun")
	assert(combat.inspiration_pickups.is_empty(), "damage without death does not drop")
	combat.damage_enemy(enemy, 10000, "bun")
	assert(combat.inspiration_pickups.size() == 1)
	var first: Dictionary = combat.inspiration_pickups[0]
	assert(first.row == 2 and first.x == 400.0 and first.amount == 1 and first.age == 0.0 and first.flight == -1.0)
	combat.damage_enemy(enemy, 10000, "bun")
	combat.damage_enemy(enemy, 10000, "pepper", false)
	assert(combat.inspiration_pickups.size() == 1 and combat.state.metrics.kills == 1, "duplicate damage cannot repeat a death")
	var reentrant := func(fallen: Dictionary) -> void: combat.damage_enemy(fallen, 10000, "bun")
	combat.enemy_fallen.connect(reentrant)
	combat.damage_enemy(spawn(combat, "flour"), 10000, "pepper", false)
	combat.enemy_fallen.disconnect(reentrant)
	assert(combat.inspiration_pickups.size() == 2 and combat.state.metrics.kills == 2, "death signals cannot repeat rewards")
	var leaked: Dictionary = spawn(combat, "gray", 1, 0.0)
	combat.step(1.0 / 60.0)
	assert(not combat.enemies.has(leaked) and combat.state.leaks == 1)
	assert(combat.inspiration_pickups.size() == 2, "leaks never drop")
	combat.summon_pair("gray")
	for summoned: Dictionary in combat.enemies.duplicate(): combat.damage_enemy(summoned, 10000, "bun")
	assert(combat.inspiration_pickups.size() == 4, "summons can drop")
	combat.damage_enemy(spawn(combat, "elite"), 10000, "bun")
	combat.damage_enemy(spawn(combat, "boss"), 10000, "bun")
	assert(combat.inspiration_pickups.size() == 6, "elite and boss can drop")
	assert(combat.inspiration_collected == 0, "waiting does not credit")
	combat.state.phase = "prepare"
	assert(not combat.collect_inspiration(first.uid))
	combat.state.phase = "battle"
	assert(combat.collect_inspiration(first.uid))
	assert(combat.inspiration_collected == 1 and first.flight == 0.0)
	assert(combat.inspiration_pickup(first.uid).is_empty())
	assert(not combat.collect_inspiration(first.uid) and not combat.collect_inspiration(-1))
	combat.step(0.2)
	assert(combat.inspiration_pickups.has(first) and first.flight == 0.2)
	combat.step(0.25)
	assert(not combat.inspiration_pickups.has(first) and combat.inspiration_collected == 1, "flight only removes visuals")
	assert(combat.inspiration_pickups[0].age > 0.45, "waiting pickups do not expire")
	combat.clear()
	assert(combat.inspiration_pickups.is_empty() and combat.inspiration_collected == 0)

	var no_drop: CombatController = combat_for(8, "hard", 0.0)
	assert(not true in drop_pattern(no_drop))
	no_drop.data.difficulties.hard.inspiration_drop_chance = 1.0
	no_drop.state.rewards_enabled = false
	assert(not true in drop_pattern(no_drop), "debug mode has no spendable drops")
	var defaults: Dictionary = {"easy": 0.02, "normal": 0.03, "hard": 0.04}
	var fresh_data := Catalog.new()
	for id: String in defaults:
		assert(fresh_data.difficulties[id].inspiration_drop_chance == defaults[id], "tests do not mutate shared definitions")

	var easy: CombatController = combat_for()
	var normal: CombatController = combat_for(42, "normal")
	var hard: CombatController = combat_for(42, "hard")
	var rng_before: int = easy.rng.state
	var easy_pattern: Array[bool] = drop_pattern(easy)
	assert(easy.rng.state == rng_before, "drop rolls do not consume gameplay randomness")
	var normal_pattern: Array[bool] = drop_pattern(normal)
	var hard_pattern: Array[bool] = drop_pattern(hard)
	var patterns: Dictionary = {"easy": easy_pattern, "normal": normal_pattern, "hard": hard_pattern}
	for tier: CombatController in [easy, normal, hard]:
		var id: String = tier.state.difficulty
		tier.clear()
		var expected_rng := RandomNumberGenerator.new()
		expected_rng.state = tier._inspiration_rng.state
		var expected: Array[bool] = []
		for index: int in range(patterns[id].size()):
			expected.append(expected_rng.randf() < defaults[id])
		assert(patterns[id] == expected, "actual deaths use the configured 2% / 3% / 4% threshold")
		tier.data.difficulties[id].reward_multiplier = 7.0
		assert(drop_pattern(tier) == expected, "clear-reward multipliers do not change drop probability")
	for index: int in range(easy_pattern.size()):
		assert(not easy_pattern[index] or normal_pattern[index])
		assert(not normal_pattern[index] or hard_pattern[index])
	assert(easy_pattern.count(true) < normal_pattern.count(true) and normal_pattern.count(true) < hard_pattern.count(true))
	easy.clear()
	for index: int in range(100): easy.rng.randf()
	assert(drop_pattern(easy) == easy_pattern, "wave replay resets drops and ignores other RNG draws")
	easy.state.wave = 2
	easy.clear()
	var second_wave: Array[bool] = drop_pattern(easy)
	assert(second_wave != easy_pattern, "each wave uses its own deterministic stream")
	easy.clear()
	assert(drop_pattern(easy) == second_wave)
	assert(drop_pattern(combat_for(43)) != easy_pattern, "run seed changes drops")

	# Integration uses actual deaths, so input timing and loss priority include the new drop path.
	var run := RunController.new()
	run.data.difficulties.easy = run.data.difficulties.easy.duplicate(true)
	run.data.difficulties.easy.inspiration_drop_chance = 1.0
	run.new_run(92)
	run.start()
	run.combat.damage_enemy(spawn(run.combat), 10000, "bun")
	var flying: Dictionary = run.combat.inspiration_pickups[0]
	run.paused = true
	assert(not run.collect_inspiration(flying.uid).is_empty())
	run.advance(0.2)
	assert(flying.age == 0.0 and flying.flight == -1.0 and run.state.collected_inspiration() == 0)
	run.paused = false
	assert(run.collect_inspiration(flying.uid).is_empty())
	run.advance(0.2)
	assert(run.combat.inspiration_pickups.has(flying) and is_equal_approx(flying.flight, 0.2))
	run.paused = true
	run.advance(0.2)
	assert(is_equal_approx(flying.flight, 0.2))
	run.paused = false
	run.speed = 2.0
	run.advance(0.15)
	assert(run.combat.inspiration_pickups.is_empty() and run.state.collected_inspiration() == 1)
	run.speed = 1.0
	run.director.cursor = run.director.events.size()
	run.state.pantry = 1
	run.state.recipes.append("burn")
	var burning: Dictionary = spawn(run.combat, "gray", 0, 0.01)
	burning.hp = 1.0
	burning.burn_time = 1.0
	burning.burn_tick = run.data.rules.burn_tick
	spawn(run.combat, "gray", 1, 0.01)
	run.advance(1.0 / 60.0)
	assert(run.state.phase == "lost" and run.state.metrics.kills == 2 and run.state.metrics.leaks == 1)
	assert(run.state.metrics.passed == 0 and run.state.collected_inspiration() == 1)
	assert(run.combat.inspiration_pickups.is_empty(), "death beats its own leak; a different fatal leak beats auto collection")

	var data := Catalog.new()
	data.progression = data.progression.duplicate(true)
	for id: String in defaults:
		data.difficulties[id] = data.difficulties[id].duplicate(true)
		for invalid: float in [-0.1, 1.1, NAN, INF]:
			data.difficulties[id].inspiration_drop_chance = invalid
			assert(not data.validate().is_empty())
		for valid: float in [0.0, 1.0, defaults[id]]:
			data.difficulties[id].inspiration_drop_chance = valid
			assert(data.validate().is_empty())
	data.progression.inspiration_drop_amount = 0
	assert(not data.validate().is_empty())
	data.progression.inspiration_drop_amount = 1
	for invalid: float in [0.0, -0.1, NAN, INF]:
		data.progression.inspiration_flight_duration = invalid
		assert(not data.validate().is_empty())
	print("PASS inspiration drops: deaths, repeated damage, summons, leaks, debug, collection, pause/speed, flight, loss priority, lifecycle, 2%/3%/4% deterministic thresholds independent of clear rewards, independent RNG and per-tier config validation")
	quit()
