extends SceneTree

func _init() -> void:
	var run := RunController.new()
	run.new_run(42)
	run.state.chapter_id = "kitchen_2"
	assert(run.data.chapter_waves("kitchen_2").size() == 8)
	var first: Resource = run.data.chapter_waves("kitchen_2")[0]
	var previous: Resource = run.data.chapter_waves("kitchen_1")[7]
	assert(first.stats.hp_scale >= previous.stats.hp_scale)
	assert(first.stats.damage_scale >= previous.stats.damage_scale)
	assert(first.stats.rows == [0,1,2,3,4,5,6])
	assert(first.stats.composition.count("runner") > first.stats.composition.size() / 3)
	for seed_value: int in range(100):
		for wave: Resource in run.data.chapter_waves("kitchen_2"):
			var random := RandomNumberGenerator.new()
			random.seed = seed_value
			var director := WaveDirector.new()
			director.begin(wave,random)
			assert(director.events.size() == wave.stats.composition.size())
			var previous_time: float = -1
			for event: Dictionary in director.events:
				assert(event.time > previous_time and event.row >= 0 and event.row < 7)
				previous_time = event.time
			assert(director.events[0].row != director.events[1].row and director.events[1].row != director.events[2].row and director.events[0].row != director.events[2].row)
	run.state.wave = 8
	run.start()
	run.director.events.clear()
	var wave: Resource = run.data.chapter_waves("kitchen_2")[7]
	run.combat.spawn("boss",3,wave)
	var boss: Dictionary = run.combat.enemies[0]
	assert(run.combat.enemy_title("boss") == "快班大厨")
	run.combat.step(12.0)
	assert(run.combat.warning_summons.size() == 1 and run.combat.enemies.size() == 1)
	assert(run.combat.warning_summons[0].rows == [0,6])
	run.paused = true
	run.advance(0.25)
	assert(run.combat.warning_summons[0].remaining == 2.0)
	run.paused = false
	run.speed = 2.0
	run.advance(0.25)
	assert(is_equal_approx(run.combat.warning_summons[0].remaining,1.5))
	run.combat.step(1.5)
	assert(run.combat.warning_summons.is_empty() and run.combat.enemies.size() == 3)
	assert(run.combat.enemies[1].id == "runner" and run.combat.enemies[1].row == 0 and run.combat.enemies[2].row == 6)
	assert(is_equal_approx(run.combat.enemies[1].max_hp,65.0*wave.stats.hp_scale))
	var before: float = boss.summon
	run.combat.damage_enemy(boss,1400,"bun")
	assert(boss.rage and is_equal_approx(boss.summon,before*10.0/12.0))
	assert(run.combat.warning_summons.size() == 1 and run.combat.warning_summons[0].id == "drummer")
	run.combat.damage_enemy(boss,1,"bun")
	assert(run.combat.warning_summons.size() == 1)
	run.combat.damage_enemy(boss,10000,"bun")
	assert(run.combat.warning_summons.is_empty())
	run.combat.step(3)
	assert(run.combat.enemies.size() == 2)
	run.combat.spawn("boss",3,wave)
	run.combat.request_summons("runner",run.combat.enemies[-1])
	run.combat.clear()
	assert(run.combat.warning_summons.is_empty())
	print("PASS chapter two: 800 schedules, telegraph, edges, scaling, pause/speed, rage progress, one-time burst, death cancellation, clear")
	quit()
