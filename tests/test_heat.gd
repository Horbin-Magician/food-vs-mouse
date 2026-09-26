extends SceneTree

func tick(run: RunController, frames: int) -> void:
	for frame: int in range(frames): run.advance(1.0 / 60.0)

func _init() -> void:
	test_wave_carry()
	var run := RunController.new()
	run.new_run(42)
	for stage: int in range(8):
		run.start()
		run.finish_wave()
	assert(run.shop.is_open())
	run.state.heat = 0
	tick(run, 60)
	assert(run.state.heat == 0, "prepare does not regenerate")
	run.new_run(42)
	run.state.heat = run.data.rules.heat_start
	run.start()
	assert(run.board.place("pudding", 0, 0, false).is_empty())
	run.state.heat = 0
	tick(run, 899)
	assert(run.combat.heat_pickups.is_empty())
	tick(run, 2)
	assert(absf(run.state.heat - 901.0 / 60.0 * 2.0) < 0.001)
	assert(run.combat.heat_pickups.size() == 1)
	var first: Dictionary = run.combat.heat_pickups[0]
	assert(first.amount == 15 and first.flight == -1)
	run.state.levels.pudding = 10
	run.state.recipes = ["caramel"]
	tick(run, 900)
	assert(run.combat.heat_pickups.size() == 1 and first.amount == 38, "merge snapshots 15 + 18 + 5")
	var before: float = run.state.heat
	run.paused = true
	var frozen: Array = run.combat.heat_pickups.duplicate(true)
	assert(not run.collect_heat(first.uid).is_empty())
	tick(run, 60)
	assert(run.combat.heat_pickups == frozen and run.state.heat == before)
	run.paused = false
	assert(run.collect_heat(first.uid).is_empty())
	assert(run.state.heat == before and first.flight == 0)
	run.collect_heat(first.uid)
	tick(run, 12)
	assert(run.state.heat < before + 1 and first.flight > 0)
	run.paused = true
	frozen = run.combat.heat_pickups.duplicate(true)
	tick(run, 60)
	assert(run.combat.heat_pickups == frozen)
	run.paused = false
	# New production during flight is a separate pickup.
	run.combat.produce_heat(run.state.units[0])
	assert(run.combat.heat_pickups.size() == 2 and run.combat.heat_pickups[1].amount == 23)
	tick(run, 15)
	assert(absf(run.state.heat - before - 38.9) < 0.001)
	assert(run.combat.heat_pickups.size() == 1)
	run.collect_heat(first.uid)
	assert(run.combat.heat_pickups[0].flight == -1, "stale UID cannot collect another pickup")
	var second: Dictionary = run.combat.heat_pickups[0]
	assert(run.board.remove(0, 0, false).is_empty())
	assert(run.collect_heat(second.uid).is_empty(), "source removal does not discard production")
	run.state.heat = run.data.rules.heat_cap - 10
	var overflow: float = run.state.metrics.overflow
	run.speed = 2
	tick(run, 13)
	assert(run.combat.heat_pickups.size() == 1 and run.state.heat < run.data.rules.heat_cap - 9)
	tick(run, 1)
	assert(run.combat.heat_pickups.is_empty() and run.state.heat == run.data.rules.heat_cap)
	assert(absf(run.state.metrics.overflow - overflow - (23 + 28.0 / 60.0 * 2.0 - 10)) < 0.001)
	# Full heat does not prevent production; permanent levels and recipes stay immutable.
	run.state.cooldowns.clear()
	assert(run.board.place("pudding", 1, 0, false).is_empty())
	run.state.heat = run.data.rules.heat_cap
	run.combat.produce_heat(run.state.units[0])
	assert(run.combat.heat_pickups[0].amount == 23)
	run.combat.damage_unit(run.state.units[0], 9999)
	assert(run.combat.heat_pickups.size() == 1)
	run.finish_wave()
	assert(run.combat.heat_pickups.size() == 1, "uncollected heat survives a wave and source death")
	assert(not run.collect_heat(second.uid).is_empty())
	run.advance(0.0)
	assert(run.combat.heat_pickups.size() == 1, "starting the next wave retains heat")
	run.new_run(44)
	run.start()
	run.board.place("pudding", 0, 0, false)
	run.combat.produce_heat(run.state.units[0])
	run.collect_heat(run.combat.heat_pickups[0].uid)
	run.state.pantry = 0
	tick(run, 1)
	assert(run.state.phase == "lost" and run.combat.heat_pickups.is_empty())
	run.new_run(45)
	assert(run.combat.heat_pickups.is_empty())
	run.start()
	run.board.place("pudding", 0, 0, false)
	run.combat.produce_heat(run.state.units[0])
	run.state.chapter_id = "kitchen_5"
	run.state.wave = 8
	run.finish_wave()
	assert(run.state.phase == "won" and run.combat.heat_pickups.is_empty())
	run.saves.folder = "user://qa_heat/"
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	run.new_run(46)
	run.start()
	run.board.place("pudding", 0, 0, false)
	run.combat.produce_heat(run.state.units[0])
	run.collect_heat(run.combat.heat_pickups[0].uid)
	assert(run.resume_run())
	assert(run.state.phase == "prepare" and run.combat.heat_pickups.is_empty() and run.state.units.is_empty())
	print("PASS heat: rate, production snapshot, merge, click, duplicate, flight, pause, speed, cap, death and lifecycle")
	quit()

func test_wave_carry() -> void:
	for timeout: bool in [false, true]:
		var run := RunController.new()
		run.new_run(57)
		run.start()
		assert(run.board.place("pudding", 0, 0, false).is_empty())
		run.combat.produce_heat(run.state.units[0])
		var flying: Dictionary = run.combat.heat_pickups[0]
		run.collect_heat(flying.uid)
		run.combat.produce_heat(run.state.units[0])
		var waiting: Dictionary = run.combat.heat_pickups[1]
		if timeout:
			run.combat.spawn("gray", 2, run.data.waves[0])
			run.director.elapsed = run.director.duration
		else:
			run.director.cursor = run.director.events.size()
		tick(run, 1)
		assert(run.state.phase == "prepare" and run.combat.heat_pickups.size() == 2)
		var frozen: Array = run.combat.heat_pickups.duplicate(true)
		run.advance(0.0)
		assert(run.combat.heat_pickups == frozen)
		var before: float = run.state.heat
		tick(run, 30)
		assert(is_equal_approx(run.state.heat, before + flying.amount + 1.0))
		assert(run.combat.heat_pickups.size() == 1 and waiting.flight < 0)
		run.combat.produce_heat(run.state.units[0])
		assert(waiting.amount == 30, "retained source merges future production")
		run.state.wave = 8
		run.finish_wave()
		assert(run.shop.is_open() and run.combat.heat_pickups.size() == 1)
		frozen = run.combat.heat_pickups.duplicate(true)
		tick(run, 60)
		assert(run.combat.heat_pickups == frozen, "shop freezes heat")
		run.start()
		assert(run.collect_heat(waiting.uid).is_empty())
		assert(not run.combat.collect_heat(waiting.uid), "repeat click cannot collect twice")
		tick(run, 30)
		assert(run.combat.heat_pickups.is_empty())
