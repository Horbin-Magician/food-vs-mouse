extends SceneTree

func arena(difficulty: String = "easy") -> RunController:
	var run := RunController.new()
	run.new_run(42, [], difficulty)
	run.start()
	run.director.cursor = run.director.events.size()
	return run

func boss(run: RunController, id: String, chapter: String) -> Dictionary:
	return run.combat.spawn(id, 3, run.data.chapter_waves(chapter)[7])

func food(run: RunController, row: int, col: int, id: String = "toast") -> Dictionary:
	run.state.heat = 9999
	run.state.cooldowns.clear()
	assert(run.board.place(id, row, col, false).is_empty())
	var result: Dictionary = run.board.at(row, col)
	result.hp = 10000.0
	result.timer = -10000.0
	return result

func _init() -> void:
	var run := arena("normal")
	var enemy: Dictionary = boss(run, "boss_ironpot", "kitchen_3")
	assert(enemy.max_hp == 3500.0 and enemy.shield == 500.0 and enemy.dps == 60.0)
	assert(enemy.hp_scale == 1.25 and enemy.damage_scale == 1.25 and enemy.rank == "boss")
	var guard: Dictionary = run.combat.spawn("rivet_guard", 0, run.data.chapter_waves("kitchen_3")[0])
	assert(is_equal_approx(guard.max_hp, 726.0))
	# Windwhistle replaces a contact attack with one dash impact, then exposes itself.
	run = arena()
	var wall: Dictionary = food(run, 3, 4)
	enemy = boss(run, "boss_windwhistle", "kitchen_2")
	enemy.x = 480.0
	run.combat.step(8.0)
	assert(enemy.ability_state == "dash_warning" and run.combat.abilities.telegraphs[0].kind == "dash")
	var hp: float = wall.hp
	run.combat.step(2.0)
	assert(enemy.ability_state == "dash_recovery" and is_equal_approx(wall.hp, hp - 60.0))
	assert(enemy.exposed == 1.2 and run.combat.enemies.size() == 1)
	var body: float = enemy.hp
	run.combat.damage_enemy(enemy, 100.0, "bun")
	assert(is_equal_approx(enemy.hp, body - 120.0))
	run.combat.step(3.0)
	assert(enemy.ability_state == "normal" and enemy.exposed == 1.0)
	run.combat.damage_enemy(enemy, enemy.hp - enemy.max_hp * 0.5, "bun")
	assert(not enemy.ability_stage)
	run.combat.damage_enemy(enemy, 1.0, "bun")
	assert(enemy.ability_stage)
	run.combat.step(6.0)
	assert(enemy.ability_state == "dash_warning")
	run.combat.step(2.0)
	assert(enemy.ability_state == "dash_recovery" and is_equal_approx(enemy.ability_remaining, 4.0))
	# Break-shell overflow uses the old state; only subsequent hits gain exposure.
	run = arena()
	enemy = boss(run, "boss_ironpot", "kitchen_3")
	run.combat.damage_enemy(enemy, 390.0, "bun")
	assert(enemy.shield == 10.0 and enemy.hp == 2800.0)
	run.combat.damage_enemy(enemy, 30.0, "bun")
	assert(enemy.shield == 0.0 and enemy.hp == 2780.0 and enemy.shell_broken)
	assert(enemy.ability_state == "shell_exposed" and enemy.exposed == 1.25)
	run.combat.damage_enemy(enemy, 8.0, "pepper", false)
	assert(enemy.hp == 2770.0)
	run.combat.step(4.0)
	assert(enemy.exposed == 1.0)
	run.combat.damage_enemy(enemy, 1400.0, "bun")
	assert(enemy.ability_stage and enemy.ability_state == "normal")
	run = arena()
	wall = food(run, 3, 4)
	enemy = boss(run, "boss_ironpot", "kitchen_3")
	enemy.x = 480.0
	enemy.ability_elapsed = 6.0
	run.combat.step(0.02)
	assert(enemy.ability_state == "heavy")
	hp = wall.hp
	run.combat.damage_enemy(enemy, 400.0, "pepper", false)
	assert(enemy.ability_state == "shell_exposed" and run.combat.abilities.telegraphs.is_empty())
	run.combat.step(2.5)
	assert(wall.hp == hp)
	# Defensive phase entry also removes a residual shell when a restored/debug state is already low.
	run = arena()
	enemy = boss(run, "boss_ironpot", "kitchen_3")
	enemy.hp = enemy.max_hp * 0.5 - 1.0
	run.combat.damage_enemy(enemy, 1.0, "bun")
	assert(enemy.shield == 0.0 and enemy.shell_broken and enemy.ability_state == "shell_exposed")
	var exposure_time: float = enemy.ability_remaining
	run.combat.step(1.0)
	run.combat.damage_enemy(enemy, 1.0, "bun")
	assert(is_equal_approx(enemy.ability_remaining, exposure_time - 1.0))
	# Starter chooses frontmost cells deterministically; flour/proof take the strongest penalty.
	run = arena()
	var bun: Dictionary = food(run, 2, 4, "bun")
	var pudding: Dictionary = food(run, 3, 3, "pudding")
	wall = food(run, 4, 4)
	enemy = boss(run, "boss_starter", "kitchen_4")
	enemy.x = 560.0
	enemy.ability_elapsed = 8.0
	run.combat.step(0.02)
	assert(enemy.ability_cells == [{"row":2,"col":4},{"row":4,"col":4}])
	run.combat.step(2.5)
	assert(enemy.ability_state == "proof_hold" and run.combat.abilities.ground_effects.size() == 2)
	bun.flour = 4.0
	assert(is_equal_approx(run.recipes.interval(bun), float(run.data.foods.bun.stats.interval) / 0.75))
	assert(run.recipes.interval(pudding) == run.data.foods.pudding.stats.interval)
	hp = bun.hp
	run.combat.step(4.0)
	assert(is_equal_approx(bun.hp, hp - 48.0) and enemy.ability_state == "proof_recovery")
	assert(enemy.exposed == 1.15 and run.combat.abilities.ground_effects.is_empty())
	run.combat.damage_enemy(enemy, 1200.0, "bun")
	assert(enemy.ability_pending_stage)
	run.combat.step(4.0)
	enemy.x = 560.0
	enemy.ability_elapsed = 8.0
	run.combat.step(0.02)
	assert(enemy.ability_cells.size() == 3)
	run.combat.step(2.5)
	hp = wall.hp
	run.combat.step(3.98)
	run.combat.damage_enemy(enemy, 10000.0, "bun")
	run.combat.step(0.05)
	assert(wall.hp == hp and run.combat.abilities.ground_effects.is_empty())
	assert(wall.proof_time == 0 and bun.proof_time == 0)
	# A due burn tick kills the caster before proof's same-step explosion.
	run = arena()
	wall = food(run, 3, 4)
	enemy = boss(run, "boss_starter", "kitchen_4")
	enemy.x = 560.0
	enemy.ability_elapsed = 8.0
	run.combat.step(2.52)
	assert(run.combat.abilities.ground_effects.size() == 1)
	run.combat.step(3.98)
	hp = wall.hp
	enemy.hp = 1.0
	enemy.burn_time = 1.0
	enemy.burn_tick = 0.99
	run.state.recipes.append("burn")
	run.combat.step(0.03)
	assert(not run.combat.enemies.has(enemy) and wall.hp == hp and run.combat.abilities.ground_effects.is_empty())
	# Two thresholds crossed before six seconds queue behind the first order.
	run = arena()
	enemy = boss(run, "boss_quartermaster", "kitchen_5")
	run.combat.damage_enemy(enemy, 2200.0, "bun")
	assert(enemy.order_flags == [false,true,true])
	run.combat.step(5.0)
	assert(enemy.order_status == "idle" and run.combat.enemies.size() == 1)
	run.combat.step(1.0)
	assert(enemy.order_status == "warning" and enemy.order_index == 0)
	assert(run.combat.abilities.telegraphs[0].rows == [2,4])
	run.combat.step(5.0)
	assert(enemy.order_status == "active" and enemy.order_remaining == 2 and run.combat.enemies.size() == 3)
	assert(run.combat.enemies[1].id == "spoon_skater" and run.combat.enemies[2].row == 4)
	assert(is_equal_approx(run.combat.enemies[1].max_hp, 80.0 * 4.48))
	run.combat.abilities.grant_shield(enemy, 100.0, 8.0)
	for child: Dictionary in run.combat.enemies.duplicate():
		if child.uid != enemy.uid: run.combat.damage_enemy(child, 10000.0, "bun")
	run.combat.step(0.02)
	assert(enemy.order_status == "failed" and enemy.shield == 0.0 and enemy.exposed == 1.25)
	assert(enemy.ability_state == "order_failed")
	run.combat.step(5.02)
	assert(enemy.order_status == "warning" and enemy.order_index == 1)
	run.combat.step(5.0)
	assert(enemy.order_status == "active" and enemy.order_remaining == 1)
	assert(run.combat.enemies[1].id == "rivet_guard")
	for child: Dictionary in run.combat.enemies.duplicate():
		if child.uid != enemy.uid: run.combat.damage_enemy(child, 10000.0, "bun")
	run.combat.step(0.02)
	run.combat.step(5.02)
	assert(enemy.order_index == 2 and enemy.order_status == "warning")
	run.combat.step(5.0)
	assert(enemy.order_remaining == 0 and run.combat.enemies[1].id == "dough_rat")
	run.combat.step(14.0)
	assert(enemy.order_status == "success" and enemy.shield > 0)
	run.combat.step(20.0)
	assert(enemy.order_status == "done" and enemy.order_sent == 3 and run.combat.enemies.size() == 3)
	# Boss death cancels pending work, while spawned escorts still block wave completion.
	run.combat.damage_enemy(enemy, 10000.0, "bun")
	assert(run.combat.enemies.size() == 2 and run.combat.abilities.telegraphs.is_empty())
	run.combat.step(30.0)
	assert(run.combat.enemies.size() == 2)
	run = arena()
	enemy = boss(run, "boss_quartermaster", "kitchen_5")
	run.combat.step(11.0)
	run.combat.enemies[1].x = -1.0
	run.combat.step(0.02)
	assert(run.state.pantry == 9 and enemy.order_status == "failed")
	# Both escorts die on the observation deadline; failure must win over success.
	run = arena()
	enemy = boss(run, "boss_quartermaster", "kitchen_5")
	run.combat.step(11.0)
	enemy.order_deadline = run.combat.abilities.clock + 0.01
	run.state.recipes.append("burn")
	for child: Dictionary in run.combat.enemies:
		if child.uid == enemy.uid: continue
		child.hp = 1.0
		child.burn_time = 1.0
		child.burn_tick = 0.99
	run.combat.step(0.02)
	assert(enemy.order_status == "failed" and enemy.shield == 0 and run.combat.enemies.size() == 1)
	run = arena()
	enemy = boss(run, "boss_quartermaster", "kitchen_5")
	run.combat.step(6.0)
	run.combat.damage_enemy(enemy, 10000.0, "bun")
	run.combat.step(10.0)
	assert(run.combat.enemies.is_empty() and run.combat.abilities.telegraphs.is_empty())
	# Direct large-step helpers and normal small steps must execute the same cycles/ticks.
	var first: RunController = arena()
	var second: RunController = arena()
	for sample: RunController in [first, second]:
		food(sample, 3, 4)
		var caster: Dictionary = sample.combat.spawn("vinegar_spitter", 3, sample.data.waves[0])
		caster.x = 560.0
	first.combat.step(16.0)
	for index: int in range(960): second.combat.step(1.0 / 60.0)
	assert(is_equal_approx(first.board.at(3,4).hp, second.board.at(3,4).hp), str([first.board.at(3,4).hp, second.board.at(3,4).hp, first.combat.enemies[0].timer, second.combat.enemies[0].timer]))
	assert(first.combat.enemies[0].ability_state == second.combat.enemies[0].ability_state)
	assert(is_equal_approx(first.combat.enemies[0].x, second.combat.enemies[0].x))
	print("PASS chapter bosses: scaling, four independent cycles, thresholds, shield overflow, strongest proof, death cancellation, three queued orders, leaks, finite shields, large-step equivalence")
	quit()
