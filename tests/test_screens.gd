extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var screen = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(screen)
	screen.saves.folder = "user://qa_screens/"
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
	assert(screen.game.run.state.phase == "prepare")
	var id: String = screen.game.run.state.run_id
	screen.game.run.state.coins = 12
	screen.game.run.persist()
	screen.show_menu()
	assert(not screen.continue_button.disabled)
	screen.request_new()
	assert(screen.overwrite.visible)
	screen.overwrite.hide()
	assert(screen.saves.load_run(screen.data).run_id == id)
	screen.continue_run()
	assert(screen.game.run.state.run_id == id and screen.game.run.state.coins == 12)
	screen.game.run.start()
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
	assert(not screen.showing_result and screen.game.run.state.run_id != id)
	assert(not screen.game.run.paused and screen.game.run.speed == 1.0)
	screen.game.run.state.wave = 8
	screen.game.run.start()
	screen.game.run.finish_wave()
	screen._process(0)
	assert(screen.showing_result and screen.game.run.state.metrics.passed == 8)
	screen.leave_result("menu")
	assert(screen.game == null and screen.continue_button.disabled)
	assert(screen.saves.write_json("run.json", {"broken":true}))
	screen.show_menu()
	assert(screen.continue_button.disabled and "不合法" in screen.notice.text)
	screen.start_new()
	assert(screen.game.run.state.phase == "prepare")
	screen.game.run.persistence = false
	screen.saves.delete_run()
	screen.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS screens: menu, restore, confirmation cancel, loss/win, freeze, replay, corrupt save")
	quit()
