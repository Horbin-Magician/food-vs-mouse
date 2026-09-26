extends SceneTree

func _init() -> void:
	var run := RunController.new()
	for id: String in ["easy", "normal", "hard"]:
		for leaks: int in [0, 2]:
			run.new_run(42)
			assert(run.select_difficulty(id).is_empty())
			var factor: float = {"easy":1.0,"normal":1.25,"hard":1.5}[id]
			for index: int in range(8):
				var coins: int = run.state.coins
				run.start()
				run.state.leaks = leaks
				run.finish_wave()
				assert(run.state.inspiration_for_wave(index,run.data) == roundi(run.data.progression.inspiration_rewards[index] * factor))
				var expected: int = 0 if index == 7 else roundi((run.data.rules.rewards[index] + (2 if leaks == 0 else 0)) * factor)
				assert(run.state.coins == coins + expected)
				run.finish_wave()
				assert(run.state.coins == coins + expected)
	# Mixed difficulties retain historical amounts across saves and retries.
	run.new_run(13)
	run.saves.folder = "user://qa_difficulty_rewards_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	assert(run.select_difficulty("hard").is_empty())
	run.start()
	run.finish_wave()
	assert(run.saves.load_meta(run.data).inspiration == 6)
	assert(run.select_difficulty("normal").is_empty())
	assert(run.resume_run())
	run.start()
	run.finish_wave()
	assert(run.saves.load_meta(run.data).inspiration == 12) # round(5 * 1.25) = 6
	var folder: String = run.saves.folder
	var blocker := FileAccess.open(folder + "blocked", FileAccess.WRITE)
	blocker.close()
	run.start()
	run.saves.folder = folder + "blocked/"
	run.finish_wave() # round(6 * 1.25) = 8; persist fails
	assert(run.state.inspiration_earned["3"] == 8)
	run.saves.folder = folder
	assert(run.select_difficulty("easy").is_empty()) # retries historical credit
	assert(run.saves.load_meta(run.data).inspiration == 20)
	assert(run.resume_run() and run.persist())
	assert(run.saves.load_meta(run.data).inspiration == 20)
	var front = load("res://scenes/front_end.tscn").instantiate()
	assert(front.run_inspiration(run.state) == 20)
	front.free()
	var payload: Dictionary = run.saves.run_payload(run.state,run.rng)
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
	assert(run.saves.load_meta(run.data).inspiration == 20)
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).inspiration == 20)
	# Final wave gets scaled inspiration in the settlement transaction.
	run.new_run(14)
	assert(run.select_difficulty("hard").is_empty())
	for index: int in range(8):
		run.start()
		run.finish_wave()
	assert(run.state.phase == "won")
	assert(run.saves.load_meta(run.data).inspiration == 124) # hard total = 104
	assert(run.saves.settle(run.state,run.data))
	assert(run.saves.load_meta(run.data).inspiration == 124)
	run.persistence = false
	run.new_run()
	run.state.rewards_enabled = false
	run.start()
	run.finish_wave()
	assert(run.state.inspiration_for_wave(0,run.data) == 0)
	print("PASS difficulty rewards: all tiers/waves, rounding, bonus, mixed saves, failed write retry, legacy, loss, win, receipts and summary")
	quit()
