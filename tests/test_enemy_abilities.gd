extends SceneTree

func arena() -> RunController:
	var run := RunController.new()
	run.new_run(42)
	run.start()
	run.director.cursor = run.director.events.size()
	return run

func mouse(run: RunController, id: String, row: int = 3) -> Dictionary:
	return run.combat.spawn(id, row, run.data.waves[0])

func food(run: RunController, row: int, col: int, id: String = "toast") -> Dictionary:
	run.state.heat = 9999
	run.state.cooldowns.clear()
	assert(run.board.place(id, row, col, false).is_empty())
	return run.board.at(row, col)

func _init() -> void:
	var run := arena()
	assert(run.combat.spawn("missing", 0, run.data.waves[0]).is_empty())
	assert(run.combat.spawn("gray", -1, run.data.waves[0]).is_empty())
	assert(run.combat.enemies.is_empty() and run.combat.enemy_title("missing") == "未知老鼠")
	run.combat.summon_pair("missing")
	run.combat.request_summons("missing", {})
	assert(run.combat.enemies.is_empty() and run.combat.warning_summons.is_empty())
	var skater: Dictionary = mouse(run, "spoon_skater")
	assert(skater.ability_duration == 0.0)
	run.combat.step(6.0)
	assert(skater.ability_phase == "windup" and run.combat.abilities.telegraphs.size() == 1)
	assert(skater.ability_duration == 2.0)
	var remaining: float = skater.ability_remaining
	run.paused = true
	run.advance(0.25)
	assert(skater.ability_remaining == remaining)
	run.paused = false
	run.speed = 2
	run.advance(0.25)
	assert(is_equal_approx(skater.ability_remaining, remaining - 0.5))
	assert(skater.ability_duration == 2.0)
	run.combat.step(1.5)
	assert(skater.ability_state == "dash")
	assert(skater.ability_duration == 3.0)
	run.combat.step(3.0)
	assert(skater.ability_state == "fatigue" and run.combat.abilities.can_attack(skater))
	run.combat.step(3.0)
	assert(skater.ability_state == "normal")
	assert(skater.ability_duration == 0.0)
	# Swept collision ends both planned segments without an extra impact hit.
	run = arena()
	var wall: Dictionary = food(run, 3, 2)
	var hp: float = wall.hp
	skater = mouse(run, "spoon_captain")
	skater.x = 300.0
	skater.ability_elapsed = 6.0
	run.combat.step(0.02)
	run.combat.step(2.6)
	assert(skater.x >= 288.0 and skater.ability_state == "fatigue" and wall.hp == hp)
	run = arena()
	skater = mouse(run, "spoon_captain")
	skater.ability_elapsed = 6.0
	run.combat.step(0.02)
	run.combat.step(2.0)
	run.combat.step(1.5)
	assert(skater.ability_state == "dash_pause")
	run.combat.step(1.0)
	assert(skater.ability_state == "dash" and skater.dash_segment == 2)
	run.combat.step(1.5)
	assert(skater.ability_state == "fatigue")
	# A newly placed target-row blocker cancels the locked switch, with no reroll.
	run = arena()
	var scout: Dictionary = mouse(run, "towel_scout", 0)
	scout.x = 860.0
	run.combat.step(0.02)
	assert(scout.ability_rows == [0,1])
	food(run, 1, 8)
	run.combat.step(2.0)
	assert(scout.row == 0 and scout.ability_once and run.combat.abilities.telegraphs.is_empty())
	run = arena()
	scout = mouse(run, "towel_scout", 6)
	scout.x = 860.0
	run.combat.step(0.02)
	run.combat.step(2.0)
	assert(scout.row == 5 and scout.ability_once)
	# Direct hits peel six finite plates; damage over time bypasses them.
	run = arena()
	var guard: Dictionary = mouse(run, "rivet_guard")
	run.combat.damage_enemy(guard, 10, "pepper", false)
	assert(guard.armor == 6 and guard.hp == guard.max_hp - 10)
	for index: int in range(6): run.combat.damage_enemy(guard, 20, "bun")
	assert(guard.armor == 0 and guard.hp == guard.max_hp - 82)
	assert(run.combat.abilities.movement_speed(guard) == 13.0)
	# A replacement at the locked grid has another UID and must not receive a stale heavy hit.
	run = arena()
	wall = food(run, 3, 4)
	var breaker: Dictionary = mouse(run, "tong_breaker")
	breaker.x = 480.0
	run.combat.step(4.0)
	assert(breaker.ability_state == "heavy")
	run.state.units.erase(wall)
	wall = food(run, 3, 4)
	hp = wall.hp
	run.combat.step(2.0)
	assert(wall.hp == hp and breaker.ability_state == "heavy_recovery")
	run = arena()
	wall = food(run, 3, 4)
	breaker = mouse(run, "rivet_foreman")
	breaker.x = 480.0
	breaker.ability_elapsed = 4.0
	run.combat.step(0.02)
	for index: int in range(6): run.combat.damage_enemy(breaker, 9, "bun")
	assert(breaker.ability_state == "heavy" and run.combat.abilities.movement_speed(breaker) == 11.0)
	# Acid locks a grid, ticks at 1/2/3 seconds, and survives its caster's death.
	run = arena()
	wall = food(run, 3, 4)
	hp = wall.hp
	var acid: Dictionary = mouse(run, "vinegar_spitter")
	acid.x = 560.0
	acid.ability_elapsed = 8.0
	run.combat.step(0.02)
	assert(run.combat.abilities.telegraphs[0].cells == [{"row":3,"col":4}])
	run.combat.step(2.0)
	assert(is_equal_approx(wall.hp, hp - 24.0))
	run.combat.damage_enemy(acid, 10000, "bun")
	run.combat.step(3.0)
	assert(is_equal_approx(wall.hp, hp - 42.0) and run.combat.abilities.ground_effects.is_empty())
	# Two same-grid sources share one clock; a delayed source does not add an extra tick.
	run = arena()
	wall = food(run, 3, 4)
	hp = wall.hp
	acid = mouse(run, "vinegar_spitter")
	acid.x = 560.0
	acid.ability_elapsed = 8.0
	var acid_two: Dictionary = mouse(run, "vinegar_spitter")
	acid_two.x = 560.0
	acid_two.ability_elapsed = 7.5
	run.combat.step(5.52)
	assert(is_equal_approx(wall.hp, hp - 48.0 - 18.0))
	assert(run.combat.abilities.ground_effects.is_empty())
	run = arena()
	food(run, 0, 4)
	food(run, 1, 4)
	food(run, 6, 4)
	acid = mouse(run, "vinegar_cellarer", 0)
	acid.x = 560.0
	acid.ability_elapsed = 12.0
	run.combat.step(0.02)
	assert(acid.ability_cells == [{"row":0,"col":4},{"row":1,"col":4}])
	# One-time dough shield, stronger-only replacement, absorption and overflow.
	run = arena()
	var dough: Dictionary = mouse(run, "dough_rat")
	run.combat.step(10.0)
	assert(dough.shield == 60.0 and dough.ability_once)
	var shield_time: float = dough.shield_time
	assert(not run.combat.abilities.grant_shield(dough, 30.0, 20.0))
	assert(dough.shield_time == shield_time)
	hp = dough.hp
	run.combat.damage_enemy(dough, 70.0, "bun")
	assert(dough.shield == 0 and dough.hp == hp - 10)
	run.combat.step(20.0)
	assert(dough.shield == 0 and dough.ability_once)
	# Concurrent ration casters are ordered by UID; one target receives once per wave.
	run = arena()
	var target: Dictionary = mouse(run, "gray")
	target.x = 500.0
	var first: Dictionary = mouse(run, "ration_keeper")
	var second: Dictionary = mouse(run, "ration_keeper")
	for keeper: Dictionary in [first, second]:
		keeper.x = 600.0
		keeper.ability_elapsed = 10.0
	run.combat.step(1.52)
	assert(target.ration_received and target.shield == 45.0)
	assert(first.ration_stock == 2 and second.ration_stock == 3)
	run.combat.damage_enemy(target, 46.0, "bun")
	first.x = target.x + 50
	second.x = target.x + 50
	first.ability_elapsed = 10
	second.ability_elapsed = 10
	run.combat.step(2.0)
	assert(target.shield == 0 and first.ration_stock == 2 and second.ration_stock == 3)
	# Piercing follows through a lethal primary hit and honors the one-empty-cell counter.
	run = arena()
	wall = food(run, 3, 4)
	wall.hp = 1.0
	var rear: Dictionary = food(run, 3, 3, "pudding")
	hp = rear.hp
	var lancer: Dictionary = mouse(run, "skewer_lancer")
	lancer.x = 480.0
	lancer.timer = 0.99
	run.combat.step(0.02)
	assert(not run.state.units.has(wall) and is_equal_approx(rear.hp, hp - 7.8))
	run = arena()
	wall = food(run, 3, 4)
	rear = food(run, 3, 2, "pudding")
	hp = rear.hp
	lancer = mouse(run, "skewer_lancer")
	lancer.x = 480.0
	lancer.timer = 0.99
	run.combat.step(0.02)
	assert(rear.hp == hp)
	var marshal: Dictionary = mouse(run, "skewer_marshal", 1)
	run.combat.damage_enemy(marshal, marshal.max_hp * 0.5, "bun")
	assert(not marshal.ability_once)
	run.combat.damage_enemy(marshal, 1, "bun")
	assert(marshal.ability_state == "red_shield")
	run.combat.step(2.0)
	assert(marshal.shield == 90.0 and marshal.ability_once)
	# A lethal hit clears telegraphs, and clear() removes all runtime effects.
	run = arena()
	acid = mouse(run, "vinegar_spitter")
	food(run, 3, 4)
	acid.x = 560.0
	acid.ability_elapsed = 8.0
	run.combat.step(0.02)
	run.combat.damage_enemy(acid, 10000, "bun")
	assert(run.combat.abilities.telegraphs.is_empty())
	run.combat.step(3)
	assert(run.combat.abilities.ground_effects.is_empty())
	run.combat.clear()
	assert(run.combat.abilities.telegraphs.is_empty() and run.combat.abilities.ground_effects.is_empty())
	print("PASS enemy abilities: eight species, four elites, swept dash, locked switch/UID, armor, acid clock, shields, finite rations, splash, pause/speed, cancellation")
	quit()
