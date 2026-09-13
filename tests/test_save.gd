extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(987654)
	var path: String = "user://qa_save/"
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
	assert(snapshot.phase == "recipe" and snapshot.choices == run.state.choices)
	var restored: RunState = run.saves.restore(snapshot)
	assert(restored.units == run.state.units and restored.coins == run.state.coins)
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.units.append(corrupt.units[0].duplicate())
	assert(not run.saves.validate(corrupt,run.data))
	corrupt = snapshot.duplicate(true)
	corrupt.coins = -1
	assert(not run.saves.validate(corrupt,run.data))
	corrupt = snapshot.duplicate(true)
	corrupt.units[0].id = "missing"
	assert(not run.saves.validate(corrupt,run.data))
	run.state.metrics.kills = 100
	run.state.metrics.passed = 4
	run.state.metrics.puddings = 3
	assert(run.saves.settle(run.state,run.data))
	var meta: Dictionary = run.saves.load_meta(run.data)
	assert(meta.kills == 100 and meta.unlocked.size() == 3)
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).kills == 100)
	var file: FileAccess = FileAccess.open(path.path_join("run.json"),FileAccess.WRITE)
	file.store_string('{"version":999,"payload":{}}')
	file.close()
	assert(run.saves.load_run(run.data).is_empty() and run.saves.error != "")
	assert(run.saves.load_meta(run.data).unlocked.size() == 3)
	for name: String in ["run.json","meta.json","runs/" + run.state.run_id.sha256_text() + ".json"]: DirAccess.remove_absolute(path.path_join(name))
	print("PASS save: roundtrip, rng, reward phase, validation, independent meta, idempotent unlocks")
	quit()
