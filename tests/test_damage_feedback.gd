extends SceneTree

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var run := RunController.new()
	run.persistence = false
	run.new_run(12)
	run.start()
	var view := DamageFeedback.new()
	root.add_child(view)
	view.bind(run, BoardProjection.new())
	var events: Array[Dictionary] = []
	run.combat.damage_resolved.connect(func(unit: Dictionary, amount: float, food: bool, direct: bool) -> void:
		events.append({"uid": unit.uid, "amount": amount, "food": food, "direct": direct}))
	run.combat.spawn("lid", 1, run.data.waves[0])
	var enemy: Dictionary = run.combat.enemies[0]
	run.combat.damage_enemy(enemy, 24.0, "bun")
	assert(events[-1].amount == 12.0 and not events[-1].food)
	run.combat.damage_enemy(enemy, 6.0, "pepper", false)
	assert(events[-1].amount == 6.0 and not events[-1].direct and enemy.armor == 2)
	assert(view.numbers[-1].text == "·6")
	var hp: float = enemy.hp
	run.combat.damage_enemy(enemy, 1000.0, "bun")
	assert(events[-1].amount == hp and view.numbers.size() == 3)
	run.combat.damage_enemy(enemy, 1000.0, "bun")
	assert(events.size() == 3)
	run.state.heat = 350
	run.board.place("toast", 1, 1, false)
	run.state.recipes.append("crust")
	var food: Dictionary = run.state.units[0]
	run.combat.damage_unit(food, 20.0)
	assert(events[-1].amount == 12.0 and events[-1].food)
	run.combat.damage_unit(food, 0.0)
	run.combat.damage_unit(food, -3.0)
	assert(events.size() == 4 and food.hp == 888)
	view.advance(0.0)
	assert(view.numbers[0].age == 0.0)
	view.advance(0.1)
	run.combat.damage_unit(food, 10.0)
	assert(is_equal_approx(view.flashes[food.uid].remaining, DamageFeedback.FLASH_TIME))
	run.combat.damage_unit(food, 10000.0)
	assert(events[-1].amount == 886.0)
	run.combat.damage_unit(food, 10.0)
	assert(events.size() == 6)
	assert(DamageFeedback.damage_text(1.25) == "1.2")
	assert(DamageFeedback.damage_text(0.01) == "<0.1")
	for i: int in range(170): view.on_damage(food, 1.0, true, true)
	assert(view.numbers.size() == DamageFeedback.MAX_NUMBERS)
	view.advance(0.8)
	assert(view.numbers.is_empty() and view.flashes.is_empty())
	view.on_damage(food, 1.0, true, true)
	run.state.phase = "prepare"
	view.advance(0.0)
	assert(view.numbers.is_empty())
	var old_combat: CombatController = run.combat
	run.new_run(13)
	view.bind(run, BoardProjection.new())
	assert(not old_combat.damage_resolved.is_connected(view.on_damage))
	assert(view.poses.is_empty() and view.flashes.is_empty())
	view.queue_free()
	await process_frame
	print("PASS damage feedback armor, burn, lethal, invalid hits, overlap, time, cap and lifecycle")
	quit()
