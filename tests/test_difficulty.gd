extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var run := RunController.new()
	var original := Catalog.new()
	var schedules: Array = []
	for difficulty: String in ["easy", "normal", "hard"]:
		run.new_run(42, [], difficulty)
		var factor: float = {"easy":1.0,"normal":1.25,"hard":1.5}[difficulty]
		for wave: Resource in run.data.waves:
			for id: String in run.data.enemies:
				run.combat.spawn(id, 0, wave)
				var enemy: Dictionary = run.combat.enemies.back()
				assert(is_equal_approx(enemy.hp, original.enemies[id].stats.hp * (1.0 if original.is_boss(id) else wave.stats.hp_scale) * factor))
				assert(enemy.hp == enemy.max_hp)
				assert(is_equal_approx(enemy.dps, original.enemies[id].stats.dps * (1.0 if original.is_boss(id) else wave.stats.damage_scale) * factor))
				assert(run.data.enemies[id].stats == original.enemies[id].stats)
		run.combat.summon_pair("gray")
		assert(is_equal_approx(run.combat.enemies.back().hp, original.enemies.gray.stats.hp * run.data.waves[7].stats.hp_scale * factor))
		run.start()
		assert(not run.has_method("select_difficulty"))
		run.paused = true
		assert(run.state.difficulty == difficulty)
		schedules.append(run.director.events.duplicate(true))
		run.finish_wave()
		assert(run.state.difficulty == difficulty and run.state.wave == 2)
		for next_wave: int in range(2, 9):
			assert(run.state.difficulty == difficulty)
			run.start()
			run.finish_wave()
	assert(schedules[0] == schedules[1] and schedules[1] == schedules[2])
	run.new_run(42)
	assert(run.state.difficulty == "easy")
	run.saves.folder = "user://qa_difficulty_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	run.new_run(42, [], "hard")
	var before: RunState = run.state
	run.new_run(99, [], "missing")
	assert(run.state == before and run.message == "未知难度")
	assert(run.resume_run() and run.state.difficulty == "hard")
	var payload: Dictionary = run.saves.run_payload(run.state, run.rng)
	payload.erase("difficulty")
	assert(run.saves.validate(payload, run.data))
	assert(run.saves.restore(payload).difficulty == "easy")
	for invalid: Variant in [null, 1, "unknown"]:
		payload.difficulty = invalid
		assert(not run.saves.validate(payload, run.data))
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_difficulty_ui_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	front.show_hub("loadout")
	assert(front.hub.difficulty == "easy")
	for id: String in ["easy", "normal", "hard"]:
		var rate: int = {"easy":2, "normal":3, "hard":4}[id]
		assert(("掉落概率 %d%%" % rate) in front.hub.find_child("Difficulty_" + id,true,false).tooltip_text)
	front.hub.find_child("Difficulty_normal",true,false).pressed.emit()
	front.hub.find_child("Difficulty_normal",true,false).pressed.emit()
	assert(front.hub.difficulty == "normal")
	front.hub.tab = "shop"
	front.hub.rebuild()
	front.hub.tab = "loadout"
	front.hub.rebuild()
	assert(front.hub.find_child("Difficulty_normal",true,false).text.begins_with("✓"))
	# Failed initial snapshot keeps the selection page available for retry.
	var folder: String = front.saves.folder
	var blocker := FileAccess.open(folder + "blocked", FileAccess.WRITE)
	blocker.close()
	front.saves.folder = folder + "blocked/"
	front.hub.find_child("Launch",true,false).pressed.emit()
	assert(front.game == null and front.hub.difficulty == "normal")
	front.saves.folder = folder
	front.hub.find_child("Launch",true,false).pressed.emit()
	var game = front.game
	assert(game.run.state.difficulty == "normal")
	assert(game.shop_surface.find_child("Difficulty_normal",true,false) == null)
	assert(game.run.state.phase == "battle" and not game.shop_overlay.visible)
	game.run.finish_wave()
	game.run.advance(0)
	game.run.changed.emit()
	assert(game.run.state.phase == "battle" and not game.shop_overlay.visible)
	assert(game.run.state.wave == 2 and game.run.state.difficulty == "normal")
	assert(game.shop_surface.find_child("Difficulty_normal",true,false) == null)
	assert(game.run.resume_run() and game.run.state.difficulty == "normal")
	assert("普通" in game.wave_status())
	var readonly_hub := CardHub.new()
	root.add_child(readonly_hub)
	readonly_hub.setup(front.saves,front.data,"loadout")
	assert(readonly_hub.difficulty == "normal")
	assert(readonly_hub.find_child("Difficulty_hard",true,false).disabled)
	readonly_hub.choose_difficulty("hard")
	assert(readonly_hub.difficulty == "normal")
	readonly_hub.queue_free()
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	print("PASS difficulty: formulas, summons, seed, fixed scene difficulty, legacy saves, invalid launch, UI selection and write retry")
	quit()
