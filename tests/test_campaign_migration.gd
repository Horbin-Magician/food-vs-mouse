extends SceneTree

var data := Catalog.new()

func _init() -> void:
	test_legacy_campaign()
	test_old_first_chapter()
	test_actual_clears_for_unlock()
	test_invalid_legacy()
	print("PASS campaign migration: v3 same chapter/board/assets, offset rewards and pickups, no skipped chapter credit, prior first-clear preserved, one-time v4 write, v2 defaults, corrupt and future versions")
	quit()

func storage(label: String) -> SaveService:
	var result := SaveService.new()
	result.folder = "/tmp/food_vs_mouse_migration_%s_%d/" % [label, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(result.folder)
	return result

func write_profile(saves: SaveService, version: int, profile: Dictionary) -> void:
	var file := FileAccess.open(saves.folder.path_join("player.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":version,"payload":profile}))
	file.close()

func legacy_profile(saves: SaveService) -> Dictionary:
	var run := RunController.new()
	run.new_run(883)
	run.start()
	assert(run.board.place("bun", 2, 0, false).is_empty())
	run.state.phase = "prepare"
	run.state.chapter_id = "kitchen_3"
	run.state.wave = 3
	run.state.metrics.passed = 2
	run.state.heat = 137.0
	run.state.pantry = 6
	run.state.units[0].hp = 111.0
	run.state.recipes = ["reheat"]
	run.state.metrics.recipes = ["reheat"]
	run.state.choices = ["pressure", "crust"]
	run.state.refreshes = 2
	run.state.inspiration_earned = {"1":4,"2":5}
	run.state.inspiration_collected = {"1":2,"3":4}
	var payload: Dictionary = saves.run_payload(run.state, run.rng)
	payload.erase("scene_id")
	payload.erase("start_wave")
	var profile: Dictionary = saves.load_profile(data)
	profile.run = payload
	profile.meta.inspiration = 90
	profile.meta.chapter_clears = {"kitchen_1":1,"kitchen_3":1}
	profile.meta.ledger[payload.run_id] = {"chapter_id":"kitchen_3","passed":2,"settled":false,"inspiration_collected":{"1":2,"3":4}}
	profile.meta.ledger["history"] = {"chapter_id":"kitchen_2","passed":8,"settled":true,"first_clear_reward":12,"inspiration_collected":{"8":1},"summary":{"chapter_id":"kitchen_2","metrics":{"passed":8}}}
	return profile

func test_legacy_campaign() -> void:
	var saves := storage("v3")
	var source: Dictionary = legacy_profile(saves)
	write_profile(saves, 3, source)
	var original_disk: String = FileAccess.get_file_as_string(saves.folder.path_join("player.json"))
	var profile: Dictionary = saves.load_profile(data)
	assert(not profile.is_empty(), saves.error)
	assert(profile.run.scene_id == "kitchen" and profile.run.chapter_id == "kitchen_3" and profile.run.wave == 3)
	assert(profile.run.start_wave == 17 and profile.run.metrics.passed == 18 and profile.run.reward_floor == 16)
	assert(profile.run.inspiration_earned["17"] == 4 and profile.run.inspiration_earned["18"] == 5)
	assert(profile.run.inspiration_collected["17"] == 2 and profile.run.inspiration_collected["19"] == 4)
	assert(profile.meta.ledger[source.run.run_id].passed == 18)
	assert(profile.meta.inspiration == 90 and profile.meta.chapter_clears.kitchen_3 == 1)
	assert(FileAccess.get_file_as_string(saves.folder.path_join("player.json")) == original_disk, "reads do not overwrite old files")
	var historical: Dictionary = profile.meta.ledger.history.duplicate(true)
	assert(saves.commit_profile(profile, int(profile.revision)), saves.error)
	assert(JSON.parse_string(FileAccess.get_file_as_string(saves.folder.path_join("player.json"))).version == 4)
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	assert(run.resume_run(), run.message)
	assert(run.state.global_wave() == 19 and run.state.run_id == source.run.run_id)
	assert(run.state.heat == 137.0 and run.state.pantry == 6 and run.state.units[0].hp == 111.0)
	assert(run.state.recipes == ["reheat"] and run.state.seed_value == 883)
	assert(not run.shop.is_open() and run.state.choices.is_empty() and run.state.refreshes == 0)
	assert(run.rng.state == int(source.run.rng), "discarding the old ordinary shop must not consume RNG")
	run.advance(0.0)
	assert(run.state.phase == "battle")
	assert(saves.collect_inspiration(run.state, 4, data) and saves.load_meta(data).inspiration == 90)
	assert(saves.collect_inspiration(run.state, 5, data) and saves.load_meta(data).inspiration == 91)
	run.finish_wave()
	for stage: int in range(20, 41):
		assert(run.state.global_wave() == stage)
		run.start()
		run.finish_wave()
	assert(run.state.phase == "won")
	profile = saves.load_profile(data)
	# Only stage 19 onward pays. Chapter 3 was cleared previously; only 4 and 5 award +12.
	assert(profile.meta.inspiration == 90 + 1 + (69 - 4 - 5) + 69 * 2 + 24)
	assert(profile.meta.chapter_clears.kitchen_1 == 1 and not profile.meta.chapter_clears.has("kitchen_2"))
	assert(profile.meta.chapter_clears.kitchen_3 == 2 and profile.meta.chapter_clears.kitchen_4 == 1 and profile.meta.chapter_clears.kitchen_5 == 1)
	assert(profile.meta.ledger.history == historical)
	assert(profile.meta.ledger[run.state.run_id].first_clear_reward == 24)
	assert(saves.settle(run.state, data) and saves.load_profile(data) == profile)

func test_old_first_chapter() -> void:
	var saves := storage("v2")
	var source: Dictionary = legacy_profile(saves)
	source.meta.erase("chapter_clears")
	source.run.erase("chapter_id")
	source.meta.ledger[source.run.run_id].erase("chapter_id")
	write_profile(saves, 2, source)
	var profile: Dictionary = saves.load_profile(data)
	assert(profile.meta.chapter_clears.is_empty() and profile.run.chapter_id == "kitchen_1")
	assert(profile.run.start_wave == 1 and profile.run.metrics.passed == 2 and profile.run.wave == 3)
	assert(profile.run.inspiration_earned["1"] == 4)
	assert(saves.commit_profile(profile, int(profile.revision)))
	assert(saves.load_run(data).chapter_id == "kitchen_1")

func test_invalid_legacy() -> void:
	for problem: String in ["wave", "passed", "key", "chapter", "ledger", "version"]:
		var saves := storage(problem)
		var source: Dictionary = legacy_profile(saves)
		match problem:
			"wave": source.run.wave = 9
			"passed": source.run.metrics.passed = 10
			"key": source.run.inspiration_collected = {"9":2}
			"chapter": source.run.chapter_id = "missing"
			"ledger": source.meta.ledger[source.run.run_id].passed = 9
		write_profile(saves, 5 if problem == "version" else 3, source)
		var before: String = FileAccess.get_file_as_string(saves.folder.path_join("player.json"))
		assert(saves.load_run(data).is_empty())
		if problem not in ["ledger", "version"]:
			assert(saves.load_meta(data).inspiration == 90, "invalid run retains valid assets")
		else:
			assert(saves.load_profile(data).is_empty())
		assert(FileAccess.get_file_as_string(saves.folder.path_join("player.json")) == before)

func test_actual_clears_for_unlock() -> void:
	var saves := storage("unlock")
	var source: Dictionary = legacy_profile(saves)
	source.run.chapter_id = "kitchen_4"
	source.run.wave = 1
	source.run.metrics.passed = 0
	source.run.inspiration_collected = {}
	source.run.inspiration_earned = {}
	source.meta.ledger[source.run.run_id] = {"chapter_id":"kitchen_4","passed":0,"settled":false,"inspiration_collected":{}}
	write_profile(saves, 3, source)
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	assert(run.resume_run())
	assert(run.state.global_wave() == run.state.start_wave and not run.shop.is_open())
	assert(run.state.choices.is_empty() and run.state.refreshes == 0)
	assert(run.rng.state == int(source.run.rng), "old standalone chapter entry is not a new shop")
	run.advance(0.0)
	assert(run.state.phase == "battle")
	run.finish_wave()
	assert(run.state.metrics.passed == 25 and run.state.start_wave == 25)
	run.state.phase = "lost"
	run.state.pantry = 0
	assert(saves.settle(run.state, data))
	assert("burn" not in saves.load_meta(data).unlocked, "skipped chapters cannot count toward four actual clears")
