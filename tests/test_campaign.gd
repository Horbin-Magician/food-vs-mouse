extends SceneTree

class FailingSave extends SaveService:
	var fail_write: bool = false
	func commit_profile(profile: Dictionary, revision: int) -> bool:
		if fail_write:
			error = "injected chapter transition write failure"
			return false
		return super.commit_profile(profile, revision)

func _init() -> void:
	var data := Catalog.new()
	assert(data.scenes.size() == 1 and data.scene_wave_count("kitchen") == 40)
	assert(data.scene_chapters("kitchen").size() == 5 and data.chapter_waves("kitchen_1").size() == 8)
	assert(data.scene_chapters("unknown").is_empty() and data.scene_wave_count("unknown") == 0)
	var saves := FailingSave.new()
	saves.folder = "/tmp/food_vs_mouse_campaign_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(saves.folder)
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	run.new_run(4321)
	assert(run.state.scene_id == "kitchen" and run.state.global_wave() == 1)
	assert(not run.shop.is_open() and run.state.choices.is_empty())
	var original: RunState = run.state
	for id: String in ["unknown", "kitchen_1", "kitchen_2", "kitchen_5"]:
		run.new_run(7, [], "easy", id)
		assert(run.state == original and not saves.load_run(data).is_empty())
	var run_id: String = run.state.run_id
	var shop_rng: String = saves.load_meta(data).rng
	var loadout: Array = run.state.loadout.duplicate(true)
	var first_snapshot: Dictionary = saves.load_run(data).duplicate(true)
	# Exercise transitions and rewards; synthetic clears do not claim gameplay balance.
	for stage: int in range(1, 41):
		assert(run.state.global_wave() == stage and run.state.run_id == run_id)
		run.start()
		assert(run.state.phase == "battle")
		if stage == 1:
			assert(run.board.place("bun", 2, 0, false).is_empty())
		if stage in [8,9,16,17,32,33,40]:
			assert(saves.collect_inspiration(run.state, 2, data))
		var boundary: bool = stage % 8 == 0
		if boundary:
			run.state.heat = 321.0
			run.state.pantry = 7
			run.state.units[0].hp = 100.0
			run.state.units[0].timer = 2.0
			run.state.units[0].flour = 2.0
		if stage == 8: saves.fail_write = true
		var rng_before_clear: int = run.rng.state
		run.finish_wave()
		assert(run.state.metrics.passed == stage and run.state.loadout == loadout)
		if stage == 8:
			assert(run.state.phase == "prepare" and run.state.chapter_id == "kitchen_2")
			assert(saves.load_meta(data).chapter_clears.is_empty())
			saves.fail_write = false
			assert(run.persist())
		if stage < 40:
			assert(run.state.phase == "prepare" and run.state.global_wave() == stage + 1)
			assert(run.shop.is_open() == boundary)
			if not boundary:
				assert(run.state.choices.is_empty() and run.rng.state == rng_before_clear)
			assert(saves.load_meta(data).rng == shop_rng, "chapter clears must not refresh the card shop")
			if boundary:
				assert(run.state.wave == 1 and run.state.heat == 321.0 and run.state.pantry == 7)
				assert(run.state.units.size() == 1 and run.state.units[0].hp == 127.0)
				# Chapter transitions keep the battlefield running; only final win or loss clears it.
				assert(run.state.units[0].timer == 2.0 and run.state.units[0].flour == 2.0)
				assert(saves.load_meta(data).chapter_clears.size() == stage / 8)
				var before: Dictionary = saves.load_meta(data)
				assert(run.resume_run() and run.persist())
				assert(saves.load_meta(data) == before)
		else:
			assert(run.state.phase == "won" and run.state.chapter_id == "kitchen_5" and run.state.wave == 8)
	var profile: Dictionary = saves.load_profile(data)
	assert(profile.run.is_empty() and profile.meta.chapter_clears.size() == 5)
	assert(profile.meta.inspiration == 69 * 5 + 12 * 5 + 14)
	assert(profile.meta.ledger[run_id].first_clear_reward == 60)
	assert(profile.meta.ledger[run_id].inspiration_collected.size() == 7)
	for stage: int in [8,9,16,17,32,33,40]: assert(profile.meta.ledger[run_id].inspiration_collected[str(stage)] == 2)
	assert(saves.settle(run.state, data) and saves.load_profile(data) == profile)
	assert(not saves.save_run(saves.restore(first_snapshot), run.rng))
	# A subsequent scene starts clean, but prior first-clear rewards remain spent.
	run.new_run(5432)
	assert(run.state.global_wave() == 1 and run.state.run_id != run_id)
	assert(run.state.heat == 150 and run.state.pantry == 10 and run.state.units.is_empty() and run.state.recipes.is_empty())
	for stage: int in range(8):
		run.start()
		run.finish_wave()
	assert(run.state.phase == "prepare" and run.state.chapter_id == "kitchen_2")
	profile = saves.load_profile(data)
	assert(profile.meta.chapter_clears.kitchen_1 == 2)
	assert(profile.meta.ledger[run.state.run_id].first_clear_reward == 0)
	var stale: RunState = saves.restore(first_snapshot)
	stale.run_id = run.state.run_id
	assert(not saves.save_run(stale, run.rng), "later clear ledger blocks rollback even with no pickups")
	run.start()
	run.state.pantry = 0
	run.advance(0.1)
	assert(run.state.phase == "lost" and saves.load_meta(data).chapter_clears.kitchen_2 == 1)
	print("PASS campaign: scene-only entry, 40 continuous transitions, resources and healing, chapter reward transaction retry, global pickup keys, resume, idempotence, repeat clear, rollback guard, failure")
	quit()
