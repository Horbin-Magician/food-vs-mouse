extends SceneTree

var front: Node

func _init() -> void:
	call_deferred("capture")

func put(id: String, row: int, col: int) -> void:
	var run: RunController = front.game.run
	run.state.cards[id] = 1
	run.state.cooldowns.clear()
	run.state.heat = 9999
	assert(run.board.place(id, row, col, false).is_empty())

func capture() -> void:
	root.size = Vector2i(1280, 720)
	front = load("res://scenes/front_end.tscn").instantiate()
	front.saves.folder = "user://qa_settings_gallery_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(front.saves.folder) == OK)
	var folder: String = front.saves.folder
	root.add_child(front)
	# The generic --qa-test entry flag must not replace this fixture's unique storage.
	front.saves.folder = folder
	front.sound.settings_path = folder.path_join("audio.cfg")
	front.sound.load_settings()
	front.audio_settings.setup(front.sound)
	front.show_menu()
	front.start_new()
	if "--quit-check" in OS.get_cmdline_user_args():
		front.game.finish_shopping()
		front.game.set_process(false)
		await process_frame
		front.open_settings()
		front.audio_settings.quit_button.pressed.emit()
		assert(front.audio_settings.leave_confirmation.visible)
		create_timer(3.0).timeout.connect(func() -> void:
			push_error("Settings quit handler did not exit within three seconds")
			quit(1))
		print("Settings quit confirmation dispatched; the production handler must exit the process")
		front.audio_settings.leave_confirmation.confirmed.emit()
		return
	front.open_settings()
	if not (await snap("shop_settings")): return
	front.audio_settings.hide()
	front.game.finish_shopping()
	front.game.run.persistence = false
	front.game.set_process(false)
	for row: int in range(7):
		put("bun", row, 1)
		put("toast", row, 5)
	put("tea", 1, 3)
	put("pepper", 2, 4)
	put("popcorn", 3, 3)
	put("noodles", 4, 3)
	put("garlic", 5, 2)
	put("pudding", 0, 0)
	put("pudding", 6, 0)
	var enemies: Array[String] = ["gray", "lid", "runner", "gnawer", "flour", "drummer", "gray"]
	for row: int in range(7):
		front.game.run.combat.spawn(enemies[row], row, front.game.run.data.waves[0])
		front.game.run.combat.enemies[-1].x = 700 + row * 22
	front.game.run.state.heat = 1000
	front.game.run.state.cooldowns.clear()
	front.game.rebuild()
	front.game.animator.bind(front.game.run, front.game.projection)
	front.game.animator.advance(1, front.game.run.combat.enemies)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		var prefix: String = "%d_" % dimensions.x
		if not (await snap(prefix + "battle")): return
		front.game.settings_button.pressed.emit()
		if not (await snap(prefix + "settings")): return
		front.audio_settings.menu_button.pressed.emit()
		if not (await snap(prefix + "confirm")): return
		front.audio_settings.leave_confirmation.hide()
		front.audio_settings.hide()
	root.size = Vector2i(1280, 720)
	print("PASS settings gallery: seven native captures in /tmp/food_settings_*.png")
	if "--manual" in OS.get_cmdline_user_args():
		front.game.set_process(true)
		print("Settings manual fixture ready: isolated saves; top-left speed, top-right settings, Esc and leave confirmation")
		return
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	quit()

func snap(label: String) -> bool:
	front.game._process(0)
	await process_frame
	await process_frame
	# Native windows can stop scheduling draws while obscured. Render this capture explicitly.
	RenderingServer.force_draw(false)
	if root.get_texture().get_image().save_png("/tmp/food_settings_" + label + ".png") != OK:
		push_error("Could not save settings capture: " + label)
		quit(1)
		return false
	return true
