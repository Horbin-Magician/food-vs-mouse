extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var run := RunController.new()
	var original := Catalog.new()
	var schedules: Array = []
	for difficulty: String in ["easy", "normal", "hard"]:
		run.new_run(42)
		var random_state: int = run.rng.state
		var choices: Array = run.state.choices.duplicate()
		assert(run.select_difficulty(difficulty).is_empty())
		assert(run.select_difficulty(difficulty).is_empty())
		assert(run.rng.state == random_state and run.state.choices == choices)
		assert(not run.select_difficulty("missing").is_empty())
		var factor: float = {"easy":1.0,"normal":1.25,"hard":1.5}[difficulty]
		for wave: Resource in run.data.waves:
			for id: String in run.data.enemies:
				run.combat.spawn(id, 0, wave)
				var enemy: Dictionary = run.combat.enemies.back()
				assert(is_equal_approx(enemy.hp, original.enemies[id].stats.hp * (1.0 if id == "boss" else wave.stats.hp_scale) * factor))
				assert(enemy.hp == enemy.max_hp)
				assert(is_equal_approx(enemy.dps, original.enemies[id].stats.dps * (1.0 if id == "boss" else wave.stats.damage_scale) * factor))
				assert(run.data.enemies[id].stats == original.enemies[id].stats)
		run.combat.summon_pair("gray")
		assert(is_equal_approx(run.combat.enemies.back().hp, original.enemies.gray.stats.hp * run.data.waves[7].stats.hp_scale * factor))
		run.start()
		assert(not run.select_difficulty("easy").is_empty())
		run.paused = true
		assert(not run.select_difficulty("hard").is_empty())
		schedules.append(run.director.events.duplicate(true))
		run.finish_wave()
		assert(run.state.difficulty == difficulty and run.state.wave == 2)
		assert(run.select_difficulty("normal").is_empty())
	assert(schedules[0] == schedules[1] and schedules[1] == schedules[2])
	run.new_run(42)
	assert(run.state.difficulty == "easy")
	run.saves.folder = "user://qa_difficulty_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	assert(run.select_difficulty("hard").is_empty())
	assert(run.resume_run() and run.state.difficulty == "hard")
	var payload: Dictionary = run.saves.run_payload(run.state, run.rng)
	payload.erase("difficulty")
	assert(run.saves.validate(payload, run.data))
	assert(run.saves.restore(payload).difficulty == "easy")
	for invalid: Variant in [null, 1, "unknown"]:
		payload.difficulty = invalid
		assert(not run.saves.validate(payload, run.data))
	var blocker := FileAccess.open(run.saves.folder + "blocked", FileAccess.WRITE)
	blocker.close()
	run.saves.folder += "blocked/"
	assert(not run.select_difficulty("easy").is_empty())
	assert(run.state.difficulty == "hard")
	run.persistence = false
	var game = load("res://scenes/main.tscn").instantiate()
	game.run = run
	root.add_child(game)
	run.persistence = false
	game.shop_surface.get_node("Difficulty_normal").pressed.emit()
	assert(run.state.difficulty == "normal")
	assert(game.shop_surface.get_node("Difficulty_normal").text.begins_with("✓"))
	game.shop_surface.get_node("Done").pressed.emit()
	assert(run.state.phase == "battle" and not game.shop_overlay.visible)
	assert("普通" in game.wave_status())
	await preload("res://tests/audio_cleanup.gd").release_scene(game, self)
	print("PASS difficulty: formulas, summons, seed, stages, save compatibility, rollback, UI")
	quit()
