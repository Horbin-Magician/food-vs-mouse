extends SceneTree

const STEP: float = 1.0 / 60.0

func _init() -> void:
	var run := active_run()
	run.advance(STEP)
	assert(run.state.wave == 1 and run.state.phase == "battle", "empty opening cannot skip a wave")
	run.director.cursor = 1
	run.advance(STEP)
	assert(run.state.wave == 1, "empty gaps cannot skip future batches")
	run.director.cursor = run.director.events.size()
	var enemy: Dictionary = run.combat.spawn("gray", 2, run.data.waves[0])
	run.advance(STEP)
	assert(run.state.wave == 1, "living enemies, including summons, prevent early completion")
	run.combat.damage_enemy(enemy, 100000, "bun", false)
	run.advance(STEP)
	assert(run.state.wave == 2 and run.state.phase == "prepare")
	var rewards: Dictionary = run.state.inspiration_earned.duplicate()
	run.finish_wave()
	assert(run.state.inspiration_earned == rewards and run.state.metrics.passed == 1)
	run.advance(0.0)
	assert(run.state.phase == "battle" and run.director.elapsed == 0.0)
	assert(run.director.duration == run.data.waves[1].stats.duration)

	run = active_run()
	run.combat.spawn("gray", 2, run.data.waves[0])
	run.director.elapsed = run.director.duration - STEP * 1.5
	run.paused = true
	run.advance(0.25)
	assert(run.state.wave == 1 and run.director.elapsed < run.director.duration)
	run.paused = false
	run.advance(STEP)
	assert(run.state.wave == 1, "cannot finish before deadline")
	run.advance(STEP)
	assert(run.state.wave == 2 and run.combat.enemies.is_empty())
	assert(run.state.metrics.kills == 0 and run.state.metrics.leaks == 0)
	assert(run.state.inspiration_collected.is_empty(), "timeout cleanup gives no kill drops")

	run = active_run()
	run.director.elapsed = run.director.duration - STEP * 1.5
	run.speed = 2.0
	run.advance(STEP)
	assert(run.state.wave == 2, "double speed advances the deadline")

	run = active_run()
	run.director.elapsed = run.director.duration - STEP * 0.5
	run.state.pantry = 1
	enemy = run.combat.spawn("gray", 2, run.data.waves[0])
	enemy.x = -100.0
	run.advance(STEP)
	assert(run.state.phase == "lost" and run.state.metrics.passed == 0)
	assert(run.state.inspiration_earned.is_empty(), "loss wins over timeout in the same step")

	for chapter: String in ["kitchen_1", "kitchen_5"]:
		run = RunController.new()
		run.new_run(937)
		run.state.chapter_id = chapter
		run.state.wave = 8
		run.start()
		var wave: Resource = run.data.chapter_waves(chapter)[7]
		run.combat.spawn(wave.stats.get("boss_id", "boss"), RunState.CENTER_ROW, wave)
		run.director.elapsed = run.director.duration
		run.advance(STEP)
		assert(run.combat.enemies.is_empty() and run.combat.warning_summons.is_empty())
		assert(run.state.metrics.kills == 0)
		if chapter == "kitchen_1":
			assert(run.shop.is_open() and run.state.chapter_id == "kitchen_2")
		else:
			assert(run.state.phase == "won" and run.state.metrics.passed == 40)
	print("PASS wave completion: timeout, early clear, gaps, summons, pause, speed, reset, loss priority, no fake kills, idempotence, chapter shop and final victory")
	quit()

func active_run() -> RunController:
	var run := RunController.new()
	run.new_run(937)
	run.start()
	return run
