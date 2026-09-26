extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(987654)
	var path: String = "user://qa_save_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path)
	run.saves.folder = path
	run.state.run_id = "qa_roundtrip"
	assert(run.saves.save_run(run.state,run.rng))
	var snapshot: Dictionary = run.saves.load_run(run.data)
	assert(not snapshot.is_empty(),run.saves.error)
	var state: RunState = run.saves.restore(snapshot)
	assert(state.offers == run.state.offers and state.cards == run.state.cards)
	var other: RandomNumberGenerator = RandomNumberGenerator.new()
	other.state = int(snapshot.rng)
	assert(other.randi() == run.rng.randi())
	run.start()
	run.board.place("bun",2,0,false)
	run.state.units[0].hp = 90.0
	for col: int in range(6):
		run.state.heat = 350
		run.state.cooldowns.clear()
		assert(run.board.place("pudding", 0, col, false).is_empty())
	run.finish_wave()
	assert(run.saves.save_run(run.state,run.rng))
	snapshot = run.saves.load_run(run.data)
	assert(snapshot.phase == "prepare" and snapshot.choices == run.state.choices)
	var restored: RunState = run.saves.restore(snapshot)
	assert(restored.units == run.state.units and restored.heat == run.state.heat)
	# Purchased recipes and remaining stock survive restore; legacy choice phase migrates once.
	for stage: int in range(2, 9):
		run.start()
		run.finish_wave()
	assert(run.shop.is_open())
	var recipe_id: String = run.state.choices[0]
	run.state.heat = run.data.rules.recipe_price + 17.5
	assert(run.shop.buy_recipe(recipe_id).is_empty())
	assert(run.saves.save_run(run.state,run.rng))
	assert(run.resume_run())
	assert(recipe_id in run.state.recipes and recipe_id not in run.state.choices)
	assert(run.state.heat == 17.5, "purchase debit survives save and restore")
	run.persistence = true
	run.state.phase = "recipe"
	assert(run.saves.save_run(run.state,run.rng))
	var legacy_heat: float = run.state.heat
	var legacy_choices: Array = run.state.choices.duplicate()
	assert(run.resume_run() and run.state.phase == "prepare")
	assert(run.state.heat == legacy_heat and run.state.choices == legacy_choices)
	var migrated_offers: Array = run.state.offers.duplicate(true)
	var migrated_rng: int = run.rng.state
	assert(run.resume_run())
	assert(run.state.offers == migrated_offers and run.rng.state == migrated_rng and run.state.heat == legacy_heat)
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.units.append(corrupt.units[0].duplicate())
	assert(not run.saves.validate(corrupt,run.data))
	corrupt = snapshot.duplicate(true)
	corrupt.heat = -1
	assert(not run.saves.validate(corrupt,run.data))
	corrupt = snapshot.duplicate(true)
	corrupt.units[0].id = "missing"
	assert(not run.saves.validate(corrupt,run.data))
	run.state.metrics.kills = 100
	assert(run.state.metrics.passed == 8)
	run.state.metrics.puddings = 3
	assert(run.saves.settle(run.state,run.data))
	var meta: Dictionary = run.saves.load_meta(run.data)
	assert(meta.kills == 100 and meta.unlocked.size() == 3)
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).kills == 100)
	var damaged: Dictionary = run.saves.load_profile(run.data)
	damaged.run = {"invalid":true}
	assert(run.saves.commit_profile(damaged,int(damaged.revision)))
	assert(run.saves.load_run(run.data).is_empty() and run.saves.error != "")
	assert(run.saves.load_meta(run.data).unlocked.size() == 3)
	print("PASS save: roundtrip, rng, reward phase, validation, independent meta, idempotent unlocks")
	quit()
