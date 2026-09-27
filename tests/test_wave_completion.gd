extends SceneTree

const STEP: float = 1.0 / 60.0

func _init() -> void:
	var catalog := Catalog.new()
	var rng := RandomNumberGenerator.new()
	for chapter: String in catalog.scene_chapters("kitchen"):
		for wave: Resource in catalog.chapter_waves(chapter):
			var director := WaveDirector.new()
			director.begin(wave, rng)
			var last_time: float = director.events.back().time
			director.advance(last_time - 0.01)
			assert(not director.finished() and not director.can_complete(0))
			director.advance(0.02)
			assert(director.finished() and not director.can_complete(0))
			director.advance(9.99)
			assert(not director.can_complete(0))
			director.advance(0.01)
			assert(director.can_complete(100))
	var run := active_run()
	run.advance(STEP)
	assert(run.state.wave == 1 and run.state.phase == "battle", "empty opening cannot skip a wave")
	run.director.cursor = 1
	run.advance(STEP)
	assert(run.state.wave == 1, "empty gaps cannot skip future batches")
	arm_countdown(run)
	var enemy: Dictionary = run.combat.spawn("gray", 2, run.data.waves[0])
	run.advance(STEP)
	assert(run.state.wave == 1, "living enemies, including summons, prevent early completion")
	run.combat.damage_enemy(enemy, 100000, "bun", false)
	run.advance(STEP)
	assert(run.state.wave == 1, "clearing enemies must not skip the ten seconds")
	run.director.elapsed = run.director.duration - STEP
	run.advance(STEP)
	assert(run.state.wave == 2 and run.state.phase == "prepare")
	var rewards: Dictionary = run.state.inspiration_earned.duplicate()
	run.finish_wave()
	assert(run.state.inspiration_earned == rewards and run.state.metrics.passed == 1)
	run.advance(0.0)
	assert(run.state.phase == "battle" and run.director.elapsed == 0.0)
	assert(is_equal_approx(run.director.duration, float(run.director.events.back().time) + 10.0))

	run = active_run()
	arm_countdown(run)
	run.combat.spawn("gray", 2, run.data.waves[0])
	run.director.elapsed = run.director.duration - STEP * 1.5
	run.paused = true
	run.advance(0.25)
	assert(run.state.wave == 1 and run.director.elapsed < run.director.duration)
	run.paused = false
	run.advance(STEP)
	assert(run.state.wave == 1, "cannot finish before deadline")
	run.advance(STEP)
	assert(run.state.wave == 2 and run.combat.enemies.size() == 1)
	var survivor: Dictionary = run.combat.enemies[0]
	var old_x: float = survivor.x
	run.advance(0.0)
	run.advance(STEP)
	assert(run.combat.enemies[0].uid == survivor.uid and survivor.x < old_x)
	run.combat.damage_enemy(survivor, 1.0, "bun", false)
	assert(survivor.hp < survivor.max_hp)
	survivor.x = -100.0
	run.advance(STEP)
	assert(run.state.metrics.leaks == 1)
	assert(run.state.metrics.kills == 0)
	assert(run.state.inspiration_collected.is_empty(), "carryover gives no kill drops")

	run = active_run()
	arm_countdown(run)
	run.director.elapsed = run.director.duration - STEP * 1.5
	run.speed = 2.0
	run.advance(STEP)
	assert(run.state.wave == 2, "double speed advances the deadline")

	run = active_run()
	arm_countdown(run)
	run.director.elapsed = run.director.duration - STEP * 0.5
	run.state.pantry = 1
	enemy = run.combat.spawn("gray", 2, run.data.waves[0])
	enemy.x = -100.0
	run.advance(STEP)
	assert(run.state.phase == "lost" and run.state.metrics.passed == 0)
	assert(run.state.inspiration_earned.is_empty(), "loss wins over timeout in the same step")

	for chapter: String in catalog.scene_chapters("kitchen"):
		for early_kill: bool in [false, true]:
			run = RunController.new()
			run.new_run(937)
			run.state.chapter_id = chapter
			run.state.wave = 8
			run.start()
			var wave: Resource = run.data.chapter_waves(chapter)[7]
			var boss: Dictionary = run.combat.spawn(wave.stats.get("boss_id", "boss"), RunState.CENTER_ROW, wave)
			var survivor_mouse: Dictionary = run.combat.spawn("gray", 0, wave)
			arm_countdown(run)
			if early_kill:
				run.combat.damage_enemy(boss, 1000000, "bun", false)
				run.advance(STEP)
				assert(run.state.phase == "battle" and run.state.wave == 8)
			run.director.elapsed = run.director.duration
			run.advance(STEP)
			if not early_kill:
				assert(run.state.phase == "battle" and run.state.chapter_id == chapter)
				assert(run.state.inspiration_earned.is_empty() and run.waiting_for_boss())
				run.combat.damage_enemy(boss, 1000000, "bun", false)
				run.advance(STEP)
			assert(run.state.metrics.kills == 1)
			if chapter == "kitchen_5":
				assert(run.state.phase == "won" and run.state.metrics.passed == 40)
				assert(run.combat.enemies.is_empty())
			else:
				assert(run.shop.is_open() and run.state.chapter_id != chapter)
				assert(run.combat.enemies.has(survivor_mouse))
				var x: float = survivor_mouse.x
				run.advance(0.25)
				assert(survivor_mouse.x == x)
				run.start()
				assert(not run.boss_defeated)
	# A leaked boss must fail instead of completing the chapter.
	run = active_run()
	run.state.wave = 8
	run.state.phase = "prepare"
	run.start()
	arm_countdown(run)
	run.director.elapsed = run.director.duration
	enemy = run.combat.spawn("boss", 3, run.data.waves[7])
	enemy.x = -100.0
	run.advance(STEP)
	assert(run.state.phase == "lost" and not run.boss_defeated)
	print("PASS wave completion: ten seconds, no early clear, carryover, movement, damage, leaks, pause, speed, reset, loss priority, idempotence, shop, boss origin and victory")
	quit()

func active_run() -> RunController:
	var run := RunController.new()
	run.new_run(937)
	run.start()
	return run

func arm_countdown(run: RunController) -> void:
	run.director.advance(float(run.director.events.back().time))
	assert(is_equal_approx(run.director.duration - run.director.elapsed, 10.0))
