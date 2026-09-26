extends SceneTree

class CanvasProbe extends Node2D:
	var feedback: EnemySkillFeedback
	var draws: int = 0
	func _draw() -> void:
		feedback.draw_ground(self)
		feedback.draw_effects(self)
		for enemy: Dictionary in feedback.combat.enemies:
			feedback.draw_unit(self, enemy, feedback.point(enemy), 72.0)
		feedback.draw_boss_panel(self)
		draws += 1

func _init() -> void:
	call_deferred("verify")

func verify() -> void:
	var run := RunController.new()
	run.new_run(2718)
	run.start()
	run.director.cursor = run.director.events.size()
	var view := EnemySkillFeedback.new()
	var projection := BoardProjection.new()
	view.bind(run, projection)
	view.bind(run, projection)
	assert(run.combat.skill_used.is_connected(view.on_skill))
	var first_combat: CombatController = run.combat
	var enemy: Dictionary = run.combat.spawn("boss_quartermaster", 3, run.data.chapter_waves("kitchen_5")[7])
	run.combat.step(6.0)
	assert(enemy.ability_phase == "windup" and run.combat.abilities.telegraphs.size() == 1)
	for index: int in range(52):
		var caster: Dictionary = run.combat.spawn("spoon_skater", index % RunState.ROWS, run.data.waves[0])
		caster.ability_elapsed = 6.0
	run.combat.step(0.02)
	assert(run.combat.abilities.telegraphs.size() == 53)
	var telegraphs: Array = run.combat.abilities.telegraphs.duplicate(true)
	var enemy_state: Dictionary = enemy.duplicate(true)
	var rng_state: int = run.rng.state
	var payload: Dictionary = run.saves.run_payload(run.state, run.rng)
	# Decorative bursts may be capped; combat-owned pending warnings must all survive.
	for index: int in range(80):
		run.combat.skill_used.emit("heavy", enemy, [])
	assert(view.effects.size() == 48)
	assert(run.combat.abilities.telegraphs == telegraphs)
	var origin: Vector2 = view.effects[-1].origin
	enemy.x -= 80.0
	assert(view.effects[-1].origin == origin)
	enemy.x = enemy_state.x
	view.advance(0.0)
	assert(view.effects[-1].age == 0.0)
	assert(view.active_boss().uid == enemy.uid and view.by_uid(enemy.uid).id == enemy.id)
	var pose: Dictionary = {"scale":Vector2.ONE,"angle":0.0,"offset":Vector2.ZERO}
	view.cast_pose(enemy, pose)
	assert(enemy == enemy_state and run.rng.state == rng_state)
	assert(run.saves.run_payload(run.state, run.rng) == payload)
	# Run actual draw methods without creating ArtCatalog or loading character atlases.
	var canvas := CanvasProbe.new()
	canvas.feedback = view
	root.add_child(canvas)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	assert(canvas.draws > 0)
	assert(run.combat.abilities.telegraphs == telegraphs and enemy == enemy_state)
	assert(run.rng.state == rng_state and run.saves.run_payload(run.state, run.rng) == payload)
	run.combat.step(0.66)
	view.advance(0.66)
	assert(view.effects.is_empty() and run.combat.abilities.telegraphs.size() == telegraphs.size())
	# Rebinding after new_run disconnects the old combat exactly once and clears local state.
	run.new_run(314)
	run.start()
	run.director.cursor = run.director.events.size()
	view.bind(run, projection)
	assert(not first_combat.skill_used.is_connected(view.on_skill))
	assert(run.combat.skill_used.is_connected(view.on_skill))
	assert(view.effects.is_empty() and view.time == 0.0)
	first_combat.skill_used.emit("heavy", enemy, [])
	assert(view.effects.is_empty())
	enemy = run.combat.spawn("spoon_skater", 2, run.data.waves[0])
	run.combat.skill_used.emit("dash", enemy, [])
	assert(view.effects.size() == 1)
	run.state.phase = "prepare"
	view.advance(0.0)
	assert(view.effects.is_empty())
	run.state.phase = "battle"
	run.combat.skill_used.emit("dash", enemy, [])
	run.state.wave = 2
	view.advance(0.0)
	assert(view.effects.is_empty() and view.wave_key == run.state.global_wave())
	# Presentation reads the combat clock; pause leaves warnings and confirmed impacts untouched.
	run.state.wave = 1
	view.advance(0.0)
	run.combat.step(6.0)
	run.combat.skill_used.emit("dash", enemy, [])
	var remaining: float = enemy.ability_remaining
	run.paused = true
	run.advance(0.25)
	view.advance(0.0)
	assert(enemy.ability_remaining == remaining and view.effects[-1].age == 0.0)
	run.paused = false
	run.speed = 2.0
	var before: float = run.state.elapsed
	run.advance(0.25)
	view.advance(run.state.elapsed - before)
	assert(is_equal_approx(view.effects[-1].age, 0.5))
	assert(is_equal_approx(enemy.ability_remaining, remaining - 0.5))
	# Runtime proof fields are removed before the checkpoint; restores have no hidden penalty.
	run.combat.clear()
	run.state.heat = 9999.0
	run.state.cooldowns.clear()
	assert(run.board.place("bun", 3, 4, false).is_empty())
	var bun: Dictionary = run.board.at(3,4)
	enemy = run.combat.spawn("boss_starter", 3, run.data.chapter_waves("kitchen_4")[7])
	enemy.x = 560.0
	enemy.ability_elapsed = 8.0
	run.combat.step(2.52)
	assert(bun.get("proof_time", 0.0) > 0)
	run.combat.clear()
	run.state.phase = "prepare"
	view.advance(0.0)
	assert(view.effects.is_empty() and run.combat.abilities.telegraphs.is_empty() and run.combat.abilities.ground_effects.is_empty())
	payload = run.saves.run_payload(run.state, run.rng)
	assert(run.saves.validate(payload, run.data))
	assert(not payload.units[0].has("proof_time") and not payload.units[0].has("proof_penalty"))
	var restored: RunState = run.saves.restore(payload)
	assert(not restored.units[0].has("proof_time") and not restored.units[0].has("proof_penalty"))
	var restored_recipes := RecipeSystem.new(restored, run.data)
	assert(restored_recipes.interval(restored.units[0]) == run.data.foods.bun.stats.interval)
	# Every new Boss ignores the old infinite summon configuration, even with a legacy wave fixture.
	for id: String in ["boss_windwhistle", "boss_ironpot", "boss_starter", "boss_quartermaster"]:
		run.combat.clear()
		run.state.units.clear()
		run.state.phase = "battle"
		enemy = run.combat.spawn(id, 3, run.data.waves[7])
		enemy.summon = 100.0
		run.combat.damage_enemy(enemy, enemy.hp * 0.6, "bun")
		run.combat.step(0.02)
		assert(not enemy.rage and run.combat.warning_summons.is_empty())
		assert(run.combat.enemies.size() == 1)
	verify_skill_frames()
	verify_skill_event_clock()
	canvas.queue_free()
	await process_frame
	print("PASS enemy presentation: binding/restart, phase cleanup, decoration cap preserves warnings, read-only drawing/RNG, pause/2x, proof checkpoint cleanup, legacy Boss isolation, impact/recovery frames, shield recipients, death, late-frame impact clock, continuous action frames")
	quit()

func verify_skill_frames() -> void:
	var run := RunController.new()
	run.new_run(1618)
	run.start()
	run.director.cursor = run.director.events.size()
	var view := EnemySkillFeedback.new()
	var projection := BoardProjection.new()
	view.bind(run, projection)
	run.state.heat = 9999.0
	assert(run.board.place("toast", 3, 4, false).is_empty())
	var breaker: Dictionary = run.combat.spawn("tong_breaker", 3, run.data.waves[0])
	breaker.x = 480.0
	run.combat.step(4.0)
	assert(breaker.ability_phase == "windup" and view.skill_frame(breaker).y == 0)
	# A real impact changes combat to recovery in the same step; its first art frame is execute.
	run.combat.step(2.0)
	assert(breaker.ability_phase == "recovery")
	assert(view.skill_frame(breaker) == Vector2i(0, 1))
	var frozen_frame: Vector2i = view.skill_frame(breaker)
	run.paused = true
	run.advance(0.25)
	view.advance(0.0)
	assert(view.skill_frame(breaker) == frozen_frame and view.effects[-1].age == 0.0)
	run.paused = false
	run.combat.step(0.25)
	view.advance(0.25)
	assert(view.skill_frame(breaker).y == 2)
	# The renderer retains a death copy while the combat entity has already been removed.
	var corpses: Array[Dictionary] = []
	run.combat.enemy_fallen.connect(func(fallen: Dictionary) -> void:
		var corpse: Dictionary = fallen.duplicate(true)
		corpse["death_age"] = 0.0
		corpses.append(corpse)
	)
	run.combat.damage_enemy(breaker, 100000.0, "bun")
	assert(corpses.size() == 1 and view.skill_frame(corpses[0]) == Vector2i(-1, -1))
	# Receiving a real ration is passive, including species with their own shield ability.
	for target_id: String in ["tong_breaker", "dough_rat", "skewer_marshal"]:
		run.new_run(1618)
		run.start()
		run.director.cursor = run.director.events.size()
		view.bind(run, projection)
		var keeper: Dictionary = run.combat.spawn("ration_keeper", 3, run.data.waves[0])
		keeper.x = 700.0
		keeper.ability_elapsed = 10.0
		var recipient: Dictionary = run.combat.spawn(target_id, 3, run.data.waves[0])
		recipient.x = 650.0
		run.combat.step(0.02)
		assert(keeper.ability_phase == "windup")
		run.combat.step(1.5)
		assert(recipient.ration_received and recipient.shield > 0 and recipient.ability_phase == "normal")
		assert(view.skill_frame(keeper).y == 1)
		assert(view.skill_frame(recipient) == Vector2i(-1, -1))

func verify_skill_event_clock() -> void:
	var run := RunController.new()
	run.new_run(1414)
	run.start()
	run.director.cursor = run.director.events.size()
	var view := EnemySkillFeedback.new()
	var projection := BoardProjection.new()
	view.bind(run, projection)
	run.state.heat = 9999.0
	assert(run.board.place("toast", 3, 4, false).is_empty())
	var breaker: Dictionary = run.combat.spawn("tong_breaker", 3, run.data.waves[0])
	breaker.x = 480.0
	run.combat.step(5.5)
	view.advance(5.5)
	assert(breaker.ability_phase == "windup" and is_equal_approx(breaker.ability_remaining, 0.5))
	# Mirror main._process: one stalled 2x frame runs thirty substeps, then refreshes the view.
	run.speed = 2.0
	var before: float = run.state.elapsed
	run.advance(0.25)
	view.advance(run.state.elapsed - before)
	assert(breaker.ability_phase == "recovery")
	assert(view.effects[-1].id == "heavy" and view.effects[-1].age < 0.02)
	assert(is_equal_approx(view.effects[-1].started_at, run.combat.abilities.clock))
	assert(view.skill_frame(breaker) == Vector2i(0, 1))
	# Sustained actions must not replay frame zero after the former 0.24-second burst window.
	for id: String in ["spoon_skater", "boss_starter"]:
		run.new_run(1414)
		run.start()
		run.director.cursor = run.director.events.size()
		view.bind(run, projection)
		if id == "boss_starter":
			run.state.heat = 9999.0
			assert(run.board.place("toast", 3, 4, false).is_empty())
		var caster: Dictionary = run.combat.spawn(id, 3, run.data.waves[0])
		caster.x = 560.0
		caster.ability_elapsed = run.data.enemies[id].skills.interval
		run.combat.step(1.0 / 60.0)
		run.combat.step(run.data.enemies[id].skills.windup)
		assert(caster.ability_phase == "action")
		run.combat.step(0.23)
		view.advance(0.23)
		var early: Vector2i = view.skill_frame(caster)
		assert(early == Vector2i(0, 1))
		run.paused = true
		run.advance(0.25)
		view.advance(0.0)
		assert(view.skill_frame(caster) == early)
		run.paused = false
		run.combat.step(0.02)
		view.advance(0.02)
		var later: Vector2i = view.skill_frame(caster)
		assert(later.y == 1 and later.x >= early.x)
		run.combat.step(0.5)
		view.advance(0.5)
		assert(view.skill_frame(caster).x > later.x)
