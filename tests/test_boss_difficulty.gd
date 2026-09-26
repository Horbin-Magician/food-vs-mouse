extends SceneTree

func arena() -> RunController:
	var run := RunController.new()
	run.new_run(42)
	run.state.wave = 8
	run.start()
	run.director.cursor = run.director.events.size()
	run.combat.spawn("boss", RunState.CENTER_ROW, run.data.waves[7])
	return run

func _init() -> void:
	var run := arena()
	var boss: Dictionary = run.combat.enemies[0]
	assert(boss.max_hp == 2600 and boss.dps == 60)
	for i: int in range(599): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 1)
	for i: int in range(2): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 3)
	assert(run.combat.enemies[1].row != run.combat.enemies[2].row)
	assert(is_equal_approx(run.combat.enemies[1].max_hp, 195.5))
	boss.summon = 5.0
	run.combat.damage_enemy(boss, 1300, "bun")
	assert(not boss.rage and boss.summon == 5.0)
	run.combat.damage_enemy(boss, 1, "bun")
	assert(boss.rage and is_equal_approx(boss.summon, 4.0))
	assert(run.combat.enemies.size() == 5)
	assert(run.combat.enemies[3].id == "lid" and run.combat.enemies[3].row != run.combat.enemies[4].row)
	assert(is_equal_approx(run.combat.enemies[3].max_hp, 508.3))
	run.combat.damage_enemy(boss, 1, "bun")
	assert(boss.summon == 4.0 and run.combat.enemies.size() == 5)
	for i: int in range(239): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 5)
	for i: int in range(2): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 7)
	assert(boss.summon < 0.04)
	# Test a full subsequent rage cycle, not just the transition.
	boss.summon = 0
	for i: int in range(479): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 7)
	for i: int in range(2): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == 9)
	run.combat.damage_enemy(boss, 10000, "bun")
	var survivors: int = run.combat.enemies.size()
	for i: int in range(600): run.combat.step(1.0 / 60.0)
	assert(run.combat.enemies.size() == survivors)
	run = arena()
	boss = run.combat.enemies[0]
	run.combat.damage_enemy(boss, 2600, "bun")
	assert(run.combat.enemies.is_empty())
	run = arena()
	boss = run.combat.enemies[0]
	run.combat.damage_enemy(boss, 1301, "bun")
	boss.summon = 7.5
	run.paused = true
	run.advance(0.25)
	assert(boss.summon == 7.5 and run.combat.enemies.size() == 3)
	run.paused = false
	run.speed = 2.0
	run.advance(0.25)
	run.advance(1.0 / 60.0)
	assert(run.combat.enemies.size() == 5 and boss.summon < 0.05)
	for w: int in range(8):
		for id: String in ["gray","runner","lid","gnawer","drummer","flour"]:
			run.combat.clear()
			run.combat.spawn(id, 0, run.data.waves[w])
			var expected: float = run.data.enemies[id].stats.hp * (1.0 + 0.1*w) * (1.15 if w >= 4 else 1.0)
			assert(is_equal_approx(run.combat.enemies[0].max_hp, expected))
			assert(is_equal_approx(run.combat.enemies[0].dps, run.data.enemies[id].stats.dps * (1.0 + 0.06*w)))
	var old_interval: float = run.data.rules.boss_rage_summon_interval
	run.data.rules.boss_rage_summon_interval = 0.0
	assert(not run.data.validate().is_empty())
	run.data.rules.boss_rage_summon_interval = old_interval
	print("PASS boss difficulty: summon cadence, half-health boundaries, progress, lethal hit, pause/speed, all wave HP and DPS")
	quit()
