extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var screen = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(screen)
	screen.saves.folder = "user://qa_screens_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(screen.saves.folder)
	screen.saves.delete_run()
	screen.show_menu()
	assert(screen.game == null and screen.continue_button.disabled)
	assert(not FileAccess.file_exists(screen.saves.folder.path_join("run.json")))
	await process_frame
	for child: Node in screen.page.get_children():
		if child is TextureRect:
			assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(child.get_rect()))
	screen.start_new()
	assert(screen.game.run.state.phase == "battle" and not screen.game.shop_overlay.visible)
	var id: String = screen.game.run.state.run_id
	var snapshot_heat: float = screen.game.run.state.heat
	screen.game.run.state.heat = 12
	screen.game.run.persist()
	screen.show_menu()
	assert(not screen.continue_button.disabled)
	screen.request_new()
	assert(screen.overwrite.visible)
	screen.overwrite.hide()
	assert(screen.saves.load_run(screen.data).run_id == id)
	screen.continue_run()
	assert(screen.game.run.state.run_id == id and screen.game.run.state.heat == snapshot_heat)
	assert(screen.game.run.state.phase == "battle")
	screen.game.run.state.pantry = 0
	screen.game.run.advance(0.1)
	screen._process(0)
	assert(screen.showing_result and screen.game.run.state.phase == "lost")
	assert(screen.game.process_mode == Node.PROCESS_MODE_DISABLED and not screen.game.visible)
	var elapsed: float = screen.game.run.state.elapsed
	await process_frame
	assert(screen.game.run.state.elapsed == elapsed)
	var good_folder: String = screen.saves.folder
	var blocker := FileAccess.open(good_folder.path_join("blocked"), FileAccess.WRITE)
	blocker.store_string("QA file prevents directory creation")
	blocker.close()
	blocker = null
	screen.saves.folder = good_folder.path_join("blocked") + "/"
	screen.leave_result("new")
	assert(screen.showing_result and not screen.notice.text.is_empty())
	screen.saves.folder = good_folder
	screen.leave_result("new")
	assert(screen.hub != null and screen.game == null)
	screen.start_new()
	assert(not screen.showing_result and screen.game.run.state.run_id != id)
	assert(not screen.game.run.paused and screen.game.run.speed == 1.0)
	for index: int in range(40):
		screen.game.run.start()
		screen.game.run.finish_wave()
		if index == 7:
			screen.game.rebuild()
			assert(screen.game.first_clear_inspiration == 12)
			assert(screen.game.earned_inspiration() == screen.run_inspiration(screen.game.run.state))
		if index < 39:
			screen._process(0)
			assert(not screen.showing_result)
	screen._process(0)
	assert(screen.showing_result and screen.game.run.state.metrics.passed == 40)
	screen.leave_result("cards")
	assert(screen.game == null and screen.hub.tab == "shop")
	assert(screen.hub.model.editable(), "result card-hub action must settle before allowing purchases")
	screen.show_menu()
	assert(screen.game == null and screen.continue_button.disabled)
	var damaged: Dictionary = screen.saves.load_profile(screen.data)
	damaged.run = {"broken":true}
	assert(screen.saves.commit_profile(damaged,int(damaged.revision)))
	screen.show_menu()
	assert(screen.continue_button.disabled and "不合法" in screen.notice.text)
	screen.start_new()
	assert(screen.game.run.state.phase == "battle" and not screen.game.shop_overlay.visible)
	screen.game.run.persistence = false
	# A migrated independent-chapter run must not report earlier chapters as played.
	screen.game.run.state.start_wave = 25
	screen.game.run.state.chapter_id = "kitchen_4"
	screen.game.run.state.wave = 2
	screen.game.run.state.metrics.passed = 25
	screen.game.run.state.phase = "lost"
	screen._process(0)
	var visible_text: String = ""
	for child: Node in screen.page.get_children():
		if child is Label: visible_text += child.text + "\n"
	assert("1 / 16" in visible_text and "旧档第 25 关接续 · 场景进度 26/40" in visible_text)
	screen.saves.delete_run()
	screen.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS screens: menu, restore, confirmation cancel, loss/win, freeze, replay, corrupt save")
	quit()
