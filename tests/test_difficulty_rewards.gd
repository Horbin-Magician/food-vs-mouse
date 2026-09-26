extends SceneTree

func _init() -> void:
	var run := RunController.new()
	for id: String in ["easy", "normal", "hard"]:
		for leaks: int in [0, 2]:
			run.new_run(42, [], id)
			var factor: float = {"easy":1.0,"normal":1.25,"hard":1.5}[id]
			for index: int in range(8):
				var heat: float = run.state.heat
				run.start()
				run.state.leaks = leaks
				run.finish_wave()
				assert(run.state.inspiration_for_wave(index,run.data) == roundi(run.data.progression.inspiration_rewards[index] * factor))
				assert(run.state.heat == heat)
				run.finish_wave()
				assert(run.state.heat == heat)
	# Fixed difficulty retains credited amounts across saves and retries.
	run.new_run(13, [], "hard")
	run.saves.folder = "user://qa_difficulty_rewards_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	assert(run.persist())
	run.start()
	run.finish_wave()
	assert(run.saves.load_meta(run.data).inspiration == 6)
	assert(run.resume_run())
	run.start()
	run.finish_wave()
	assert(run.saves.load_meta(run.data).inspiration == 14) # round(5 * 1.5) = 8
	var folder: String = run.saves.folder
	var blocker := FileAccess.open(folder + "blocked", FileAccess.WRITE)
	blocker.close()
	run.start()
	run.saves.folder = folder + "blocked/"
	run.finish_wave() # round(6 * 1.5) = 9; persist fails
	assert(run.state.inspiration_earned["3"] == 9)
	run.saves.folder = folder
	assert(run.persist()) # retries historical credit
	assert(run.saves.load_meta(run.data).inspiration == 23)
	assert(run.resume_run() and run.persist())
	assert(run.saves.load_meta(run.data).inspiration == 23)
	var front = load("res://scenes/front_end.tscn").instantiate()
	assert(front.run_inspiration(run.state) == 23)
	front.free()
	var payload: Dictionary = run.saves.run_payload(run.state,run.rng)
	# Pre-change mixed-difficulty records remain authoritative on resume.
	var mixed: Dictionary = payload.duplicate(true)
	mixed.difficulty = "normal"
	mixed.inspiration_earned = {"1":6,"2":6,"3":8}
	assert(run.saves.validate(mixed,run.data))
	var legacy_mixed: RunState = run.saves.restore(mixed)
	assert(legacy_mixed.difficulty == "normal")
	assert(legacy_mixed.inspiration_for_wave(0,run.data) == 6)
	assert(legacy_mixed.inspiration_for_wave(1,run.data) == 6)
	assert(legacy_mixed.inspiration_for_wave(2,run.data) == 8)
	payload.erase("inspiration_earned")
	assert(run.saves.validate(payload,run.data))
	var old: RunState = run.saves.restore(payload)
	assert(old.inspiration_for_wave(0,run.data) == 4)
	for invalid: Variant in [null, [], {"9":3}, {"1":1.5}, {"1":-1}, {"4":8}]:
		payload.inspiration_earned = invalid
		assert(not run.saves.validate(payload,run.data))
	run.start()
	run.state.pantry = 0
	run.advance(0.02)
	assert(run.state.phase == "lost")
	assert(run.saves.load_meta(run.data).inspiration == 23)
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).inspiration == 23)
	# Final wave gets scaled inspiration in the settlement transaction.
	run.new_run(14, [], "hard")
	assert(run.persist())
	for index: int in range(8):
		run.start()
		run.finish_wave()
	assert(run.state.phase == "won")
	assert(run.saves.load_meta(run.data).inspiration == 127) # hard total = 104
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).inspiration == 127)
	run.persistence = false
	run.new_run()
	run.state.rewards_enabled = false
	run.start()
	run.finish_wave()
	assert(run.state.inspiration_for_wave(0,run.data) == 0)
	print("PASS difficulty rewards: all tiers/waves, rounding, no heat reward, fixed difficulty saves, failed write retry, legacy, loss, win, receipts and summary")
	quit()
