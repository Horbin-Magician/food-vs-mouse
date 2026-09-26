extends SceneTree

class FailingSave extends SaveService:
	var fail_write: bool = false
	var attempts: int = 0
	func commit_profile(profile: Dictionary, revision: int) -> bool:
		attempts += 1
		if fail_write:
			error = "injected chapter shop write failure"
			return false
		return super.commit_profile(profile, revision)

func _init() -> void:
	test_continuous_checkpoints()
	test_failed_autostart()
	test_legacy_shop_windows()
	print("PASS chapter shop: four chapter shops, automatic small waves, every-wave checkpoints, fifth boss victory, business guards, retryable writes, legacy windows and RNG")
	quit()

func storage(label: String) -> FailingSave:
	var saves := FailingSave.new()
	saves.folder = "user://qa_chapter_shop_%s_%d/" % [label, Time.get_ticks_usec()]
	assert(DirAccess.make_dir_recursive_absolute(saves.folder) == OK)
	return saves

func test_continuous_checkpoints() -> void:
	var run := RunController.new()
	run.saves = storage("continuous")
	run.persistence = true
	run.new_run(782)
	assert(run.state.phase == "prepare" and not run.shop.is_open())
	assert(run.state.choices.is_empty() and run.state.refreshes == 0)
	var untouched := RandomNumberGenerator.new()
	untouched.seed = 782
	assert(run.rng.state == untouched.state, "new games do not consume shop randomness")
	var heat: float = run.state.heat
	assert(not run.shop.refresh().is_empty() and not run.shop.buy_recipe("reheat").is_empty())
	assert(run.state.heat == heat and run.rng.state == untouched.state)
	run.advance(0.0)
	assert(run.state.phase == "battle")
	var shops: int = 0
	for stage: int in range(1, 41):
		assert(run.state.phase == "battle" and run.state.global_wave() == stage)
		var checkpoint: Dictionary = run.saves.load_run(run.data)
		assert(checkpoint.phase == "prepare" and run.saves.payload_global_wave(checkpoint, run.data) == stage)
		assert(checkpoint.metrics.passed == stage - 1)
		var active_rng: int = run.rng.state
		run.advance(0.0)
		assert(run.rng.state == active_rng, "zero-time updates cannot restart an active wave")
		if stage == 1:
			assert(run.board.place("bun", 2, 0, false).is_empty())
			# A battle exit restores this small wave, not the previous chapter shop.
			assert(run.resume_run())
			assert(not run.shop.is_open() and run.state.units == checkpoint.units)
			assert(run.state.heat == checkpoint.heat)
			run.advance(0.0)
			assert(run.board.place("bun", 2, 0, false).is_empty())
		var before_clear: int = run.rng.state
		run.finish_wave()
		assert(run.state.metrics.passed == stage)
		if stage == 40:
			assert(run.state.phase == "won" and not run.shop.is_open())
			break
		assert(run.state.phase == "prepare" and run.state.global_wave() == stage + 1)
		checkpoint = run.saves.load_run(run.data)
		assert(checkpoint.metrics.passed == stage and run.saves.payload_global_wave(checkpoint, run.data) == stage + 1)
		if stage % 8 == 0:
			shops += 1
			assert(run.shop.is_open())
			var choices: Array = run.state.choices.duplicate()
			var shop_rng: int = run.rng.state
			run.advance(0.0)
			run.advance(0.2)
			assert(run.state.phase == "prepare" and run.state.choices == choices and run.rng.state == shop_rng)
			assert(run.resume_run())
			assert(run.shop.is_open() and run.state.choices == choices and run.rng.state == shop_rng)
			run.advance(0.0)
			assert(run.state.phase == "prepare", "continuing a shop waits for shopping completion")
			run.start()
		else:
			assert(not run.shop.is_open() and run.state.choices.is_empty() and run.state.refreshes == 0)
			assert(run.rng.state == before_clear, "ordinary clears cannot roll invisible merchandise")
			heat = run.state.heat
			assert(not run.shop.refresh().is_empty() and not run.shop.buy_recipe("reheat").is_empty())
			assert(run.state.heat == heat and run.rng.state == before_clear)
			run.advance(0.0)
	assert(shops == 4)
	var profile: Dictionary = run.saves.load_profile(run.data)
	assert(profile.run.is_empty() and profile.meta.chapter_clears.size() == 5)
	run.finish_wave()
	run.advance(0.0)
	assert(run.state.phase == "won" and run.saves.load_profile(run.data) == profile)

func test_failed_autostart() -> void:
	var saves := storage("failure")
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	run.new_run(819)
	saves.fail_write = true
	run.advance(0.0)
	assert(run.state.phase == "prepare" and not run.shop.is_open())
	var attempts: int = saves.attempts
	var rng_before: int = run.rng.state
	for index: int in range(3): run.advance(0.1)
	assert(saves.attempts == attempts and run.rng.state == rng_before, "failed automatic start waits for explicit retry")
	saves.fail_write = false
	run.start()
	assert(run.state.phase == "battle")
	assert(run.board.place("bun", 2, 0, false).is_empty())
	run.state.units[0].hp = 100.0
	saves.fail_write = true
	run.finish_wave()
	assert(run.state.phase == "prepare" and run.state.wave == 2 and run.state.units[0].hp == 127.0)
	run.advance(0.0)
	attempts = saves.attempts
	for index: int in range(3): run.advance(0.1)
	assert(run.state.phase == "prepare" and saves.attempts == attempts)
	assert(saves.load_run(run.data).wave == 1 and saves.load_meta(run.data).inspiration == 0)
	saves.fail_write = false
	run.start()
	assert(run.state.phase == "battle" and run.state.wave == 2 and run.state.units[0].hp == 127.0)
	assert(saves.load_run(run.data).wave == 2 and saves.load_meta(run.data).inspiration == 4)
	for stage: int in range(2, 9):
		run.finish_wave()
		run.advance(0.0)
	assert(run.shop.is_open())
	var choices: Array = run.state.choices.duplicate()
	rng_before = run.rng.state
	saves.fail_write = true
	run.start()
	assert(run.shop.is_open() and run.state.choices == choices and run.rng.state == rng_before)
	saves.fail_write = false
	run.start()
	assert(run.state.phase == "battle" and saves.load_run(run.data).wave == 1)
	assert(saves.load_meta(run.data).chapter_clears.kitchen_1 == 1)

func test_legacy_shop_windows() -> void:
	for fixture: Dictionary in [
		{"label":"new", "chapter":"kitchen_1", "wave":1, "start":1, "phase":"prepare", "shop":false},
		{"label":"ordinary", "chapter":"kitchen_1", "wave":3, "start":1, "phase":"prepare", "shop":false},
		{"label":"recipe", "chapter":"kitchen_1", "wave":3, "start":1, "phase":"recipe", "shop":false},
		{"label":"boundary", "chapter":"kitchen_2", "wave":1, "start":1, "phase":"prepare", "shop":true},
		{"label":"boundary_recipe", "chapter":"kitchen_2", "wave":1, "start":1, "phase":"recipe", "shop":true},
		{"label":"independent_start", "chapter":"kitchen_3", "wave":1, "start":17, "phase":"prepare", "shop":false},
	]:
		var saves := storage(fixture.label)
		var source := RunController.new()
		source.new_run(823)
		source.state.chapter_id = fixture.chapter
		source.state.wave = fixture.wave
		source.state.start_wave = fixture.start
		source.state.metrics.passed = source.state.global_wave() - 1
		source.state.reward_floor = source.state.metrics.passed
		source.state.phase = fixture.phase
		source.state.heat = 317.5
		source.state.recipes = ["reheat"]
		source.state.metrics.recipes = ["reheat"]
		source.recipes.offer(source.rng, [])
		source.state.refreshes = 1
		var choices: Array = source.state.choices.duplicate()
		var rng_before: int = source.rng.state
		assert(saves.save_run(source.state, source.rng), saves.error)
		var run := RunController.new()
		run.saves = saves
		run.persistence = true
		assert(run.resume_run(), run.message)
		assert(run.shop.is_open() == fixture.shop)
		assert(run.state.phase == "prepare" and run.state.heat == 317.5 and run.state.recipes == ["reheat"])
		assert(run.state.run_id == source.state.run_id and run.rng.state == rng_before)
		if fixture.shop:
			assert(run.state.choices == choices and run.state.refreshes == 1)
		else:
			assert(run.state.choices.is_empty() and run.state.offers.is_empty() and run.state.refreshes == 0)
		assert(run.resume_run() and run.rng.state == rng_before, "repeated legacy continuation cannot reroll")
		run.advance(0.0)
		assert(run.state.phase == ("prepare" if fixture.shop else "battle"))
