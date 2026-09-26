extends SceneTree

func put(run: RunController, id: String, row: int, col: int) -> Dictionary:
	run.state.cards[id] = 1
	run.state.heat = 9999
	run.state.cooldowns.clear()
	assert(run.board.place(id, row, col, false).is_empty())
	return run.state.units[-1]

func _init() -> void:
	var run := RunController.new()
	run.new_run(42)
	run.state.wave = 8
	run.start()
	run.director.cursor = run.director.events.size()
	var view := StatusFeedback.new()
	view.bind(run, BoardProjection.new())
	run.state.recipes.assign(["breakfast", "crust", "pressure", "burn", "cold_spice", "wide"])
	var garlic: Dictionary = put(run, "garlic", 3, 2)
	var bun: Dictionary = put(run, "bun", 3, 3)
	var pudding: Dictionary = put(run, "pudding", 2, 3)
	var toast: Dictionary = put(run, "toast", 2, 2)
	put(run, "garlic", 4, 3)
	put(run, "garlic", 2, 4)
	bun.attacks = 3
	view.advance(0)
	assert(view.statuses[bun.uid] == ["haste", "power", "pressure"])
	assert(view.statuses[pudding.uid].is_empty())
	assert(view.statuses[toast.uid] == ["crust"])
	assert(is_equal_approx(run.recipes.interval(bun), 1.5 / 1.15))
	run.board.remove(garlic.row, garlic.col, false)
	view.advance(0)
	assert(view.statuses[bun.uid].count("haste") == 1)
	run.board.remove(4, 3, false)
	run.board.remove(2, 3, false)
	view.advance(0)
	assert(view.statuses[bun.uid] == ["pressure"])
	bun.attacks = 4
	view.advance(0)
	assert(view.statuses[bun.uid].is_empty())

	run.combat.spawn("drummer", 1, run.data.waves[7])
	var drummer: Dictionary = run.combat.enemies[-1]
	drummer.x = 500
	run.combat.spawn("lid", 1, run.data.waves[7])
	var enemy: Dictionary = run.combat.enemies[-1]
	enemy.x = 644
	view.advance(0)
	assert(view.statuses[enemy.uid] == ["drum", "armor"])
	assert(not "drum" in view.statuses[drummer.uid])
	enemy.x += 0.01
	view.advance(0)
	assert(not "drum" in view.statuses[enemy.uid])
	enemy.x = 500
	enemy.row = 2
	view.advance(0)
	assert(not "drum" in view.statuses[enemy.uid])
	enemy.row = 1
	run.combat.hit({"source": "tea", "damage": 1.0, "radius": 0.0}, enemy)
	run.combat.hit({"source": "pepper", "damage": 1.0, "radius": 0.0}, enemy)
	view.advance(0)
	assert(view.statuses[enemy.uid] == ["drum", "slow", "burn", "armor"])
	assert(view.effects[-1].id == "cold_spice")
	run.combat.damage_enemy(enemy, 1, "pepper", false)
	assert(enemy.armor == 1)
	run.combat.damage_enemy(enemy, 1, "bun")
	run.combat.damage_enemy(drummer, 10000, "bun")
	view.advance(0)
	assert(view.statuses[enemy.uid] == ["slow", "burn"])
	run.combat.step(3.1)
	view.advance(3.1)
	assert(view.statuses[enemy.uid].is_empty())

	run.combat.spawn("flour", bun.row, run.data.waves[7])
	var flour: Dictionary = run.combat.enemies[-1]
	flour.x = bun.col * 96 + 48
	run.combat.damage_enemy(flour, 10000, "bun")
	view.advance(0)
	assert(view.statuses[bun.uid] == ["flour"] and view.effects[-1].id == "flour")
	run.combat.damage_enemy(flour, 10000, "bun")
	assert(view.effects.filter(func(e: Dictionary) -> bool: return e.id == "flour").size() == 1)
	bun.flour = 0
	# Real impact radius is copied before the killed target is removed.
	run.combat.hit({"source": "popcorn", "damage": 10000.0, "radius": 84.0}, enemy)
	assert(view.effects[-1].id == "popcorn")
	assert(is_equal_approx(view.effects[-1].radius, 84.0 * 738.0 / 864.0))
	var position: Vector2 = view.effects[-1].origin
	enemy.x = 0
	assert(view.effects[-1].origin == position)

	view.effects.clear()
	run.combat.spawn("boss", 3, run.data.waves[7])
	var boss: Dictionary = run.combat.enemies[-1]
	boss.x = 650
	boss.summon = 9.99
	run.combat.step(0.02)
	assert(view.effects[-1].id == "summon" and view.effects[-1].targets.size() == 2)
	var targets: Array = view.effects[-1].targets
	assert(targets[0].y != targets[1].y)
	assert(targets[0] == view.point(run.combat.enemies[-2]))
	assert(targets[1] == view.point(run.combat.enemies[-1]))
	run.combat.damage_enemy(boss, 1301, "bun")
	view.advance(0)
	assert("rage" in view.statuses[boss.uid])
	assert(view.effects[-2].id == "rage" and view.effects[-1].id == "reinforce")
	var count: int = view.effects.size()
	run.combat.damage_enemy(boss, 1, "bun")
	assert(view.effects.size() == count)
	var random_state: int = run.rng.state
	view.advance(0)
	assert(view.effects[-1].age == 0)
	view.advance(0.2)
	assert(is_equal_approx(view.effects[-1].age, 0.2))
	assert(run.rng.state == random_state)
	view.advance(1.2)
	assert(view.effects.is_empty())
	# Healing survives the battle -> prepare boundary; old combat casts do not.
	run.combat.produce_heat(bun)
	bun.hp -= 10
	run.board.heal(0.15)
	run.state.phase = "prepare"
	view.advance(0)
	assert(view.effects.size() == 1 and view.effects[0].id == "heal")
	for i: int in range(90): view.on_heal(bun)
	assert(view.effects.size() == StatusFeedback.MAX_EFFECTS)
	var halo: Texture2D = view.compact_halo(["slow", "burn", "armor"])
	assert(halo == view.compact_halo(["slow", "burn", "armor"]))
	assert(halo.get_width() == 128 and halo.get_height() == 56)
	var old_combat: CombatController = run.combat
	var old_board: BoardController = run.board
	run.new_run(43)
	view.bind(run, BoardProjection.new())
	assert(view.effects.is_empty() and view.statuses.is_empty())
	assert(view.halo_cache.is_empty())
	assert(not old_combat.skill_used.is_connected(view.on_skill))
	assert(not old_board.healed.is_connected(view.on_heal))
	print("PASS status feedback: aura bounds, stacking, expiry, armor, snapshots, boss skills, clock, RNG and lifecycle")
	quit()
