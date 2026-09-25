extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_shop_flow/"
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	front.saves.delete_run()
	front.show_menu()
	front.start_new()
	var scene = front.game
	assert(scene.run.state.phase == "prepare" and scene.shop_overlay.visible)
	assert(not scene.run.board.has_method("repair"))
	assert(not scene.run.data.rules.has("repair") and not scene.run.data.rules.has("repair_cost"))
	var footer_count: int = 0
	for node: Node in scene.ui.get_children():
		if node is Button and node.position.y == scene.FOOTER_Y:
			footer_count += 1
	assert(footer_count == 2)
	var cancel := InputEventAction.new()
	cancel.action = "cancel_selection"
	cancel.pressed = true
	scene._input(cancel)
	assert(scene.shop_overlay.visible and scene.run.state.phase == "prepare")
	var saved_folder: String = front.saves.folder
	var blocker := FileAccess.open(saved_folder.path_join("blocked"), FileAccess.WRITE)
	blocker.close()
	blocker = null
	front.saves.folder = saved_folder.path_join("blocked") + "/"
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "prepare" and scene.shop_overlay.visible)
	assert(not scene.run.message.is_empty())
	front.saves.folder = saved_folder
	# Old repaired flag is accepted but has no effect on coins or HP.
	scene.run.state.repaired = true
	scene.run.persist()
	var coins: int = scene.run.state.coins
	front.show_menu()
	front.continue_run()
	scene = front.game
	assert(scene.run.state.repaired and scene.run.state.coins == coins)
	assert(scene.shop_overlay.visible)
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	var rng: int = scene.run.rng.state
	scene.finish_shopping()
	assert(scene.run.rng.state == rng)
	scene.run.finish_wave()
	scene.run.combat.clear()
	scene.rebuild()
	assert(scene.run.state.wave == 2 and scene.shop_overlay.visible)
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	scene.pause_button.pressed.emit()
	assert(scene.run.paused)
	var elapsed: float = scene.run.state.elapsed
	scene.run.advance(0.2)
	assert(scene.run.state.elapsed == elapsed)
	scene.speed_button.pressed.emit()
	assert(scene.run.speed == 2)
	scene.pause_button.pressed.emit()
	scene.run.advance(0.1)
	assert(scene.run.state.elapsed > elapsed + 0.18)
	front.saves.delete_run()
	front.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS shop flow: menu, restore, completion, duplicate start, save failure, legacy repair, next wave, pause, speed")
	quit()
