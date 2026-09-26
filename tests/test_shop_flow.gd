extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_shop_flow_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(front.saves.folder) == OK)
	front.show_menu()
	front.start_new()
	var scene = front.game
	scene.set_process(false)
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	assert(scene.run.state.choices.is_empty() and scene.run.state.refreshes == 0)
	assert(not scene.run.board.has_method("repair"))
	assert(not scene.run.data.rules.has("repair") and not scene.run.data.rules.has("repair_cost"))
	var footer_count: int = 0
	for node: Node in scene.ui.get_children():
		if node is Button and node.position.y >= 670.0:
			footer_count += 1
	assert(footer_count == 0)
	# The first save is still a preparation snapshot; continuing starts it directly.
	var id: String = scene.run.state.run_id
	var opening_snapshot: Dictionary = front.saves.load_run(front.data)
	assert(opening_snapshot.phase == "prepare" and opening_snapshot.choices.is_empty())
	front.show_menu()
	front.continue_run()
	scene = front.game
	scene.set_process(false)
	assert(scene.run.state.run_id == id and scene.run.state.phase == "battle")
	assert(not scene.shop_overlay.visible)
	# Ordinary waves auto-start; no shopping, refreshes or gameplay RNG are consumed before start.
	for wave: int in range(1, 8):
		assert(scene.run.state.wave == wave and scene.run.state.phase == "battle")
		var before_clear_rng: int = scene.run.rng.state
		scene.run.finish_wave()
		scene.rebuild()
		assert(not scene.shop_overlay.visible and not scene.run.shop.is_open())
		assert(scene.run.state.choices.is_empty() and scene.run.state.refreshes == 0)
		assert(scene.run.rng.state == before_clear_rng)
		scene._process(0)
		assert(scene.run.state.wave == wave + 1 and scene.run.state.phase == "battle")
	# The first boss opens exactly one shop for 2-1.
	scene.run.state.heat = 1400
	scene.run.finish_wave()
	scene.rebuild()
	scene._process(0)
	assert(scene.run.state.chapter_id == "kitchen_2" and scene.run.state.wave == 1)
	assert(scene.run.state.phase == "prepare" and scene.shop_overlay.visible and scene.run.shop.is_open())
	var cancel := InputEventAction.new()
	cancel.action = "cancel_selection"
	cancel.pressed = true
	scene._input(cancel)
	assert(scene.shop_overlay.visible and scene.run.state.phase == "prepare")
	var recipe_id: String = scene.run.state.choices[0]
	scene.shop_surface.get_node("Recipe_" + recipe_id).pressed.emit()
	assert(recipe_id in scene.run.state.recipes and recipe_id not in scene.run.state.choices)
	var purchased_heat: float = scene.run.state.heat
	scene.run.shop.buy_recipe(recipe_id)
	assert(scene.run.state.heat == purchased_heat)
	scene.shop_refresh.pressed.emit()
	assert(scene.run.state.refreshes == 1)
	var expected_choices: Array = scene.run.state.choices.duplicate()
	var saved_folder: String = front.saves.folder
	var blocker := FileAccess.open(saved_folder.path_join("blocked"), FileAccess.WRITE)
	blocker.close()
	blocker = null
	front.saves.folder = saved_folder.path_join("blocked") + "/"
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "prepare" and scene.shop_overlay.visible)
	assert(not scene.run.message.is_empty())
	front.saves.folder = saved_folder
	# Old repaired remains inert; a boundary continuation restores the same transaction.
	scene.run.state.repaired = true
	assert(scene.run.persist())
	var heat: float = scene.run.state.heat
	var earned: int = front.saves.load_meta(front.data).inspiration
	front.show_menu()
	front.continue_run()
	scene = front.game
	scene.set_process(false)
	assert(scene.run.state.repaired and scene.run.state.heat == heat)
	assert(scene.shop_overlay.visible and scene.run.state.phase == "prepare")
	assert(scene.run.state.choices == expected_choices and scene.run.state.refreshes == 1)
	assert(recipe_id in scene.run.state.recipes and front.saves.load_meta(front.data).inspiration == earned)
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	var rng: int = scene.run.rng.state
	scene.finish_shopping()
	assert(scene.run.rng.state == rng)
	# An ordinary snapshot failure must show a retry action without opening the shop.
	front.saves.folder = saved_folder.path_join("blocked") + "/"
	scene.run.finish_wave()
	scene.rebuild()
	scene._process(0)
	assert(scene.run.state.phase == "prepare" and scene.run.state.wave == 2)
	assert(not scene.shop_overlay.visible and not scene.run.message.is_empty())
	var failed_rng: int = scene.run.rng.state
	scene._process(0)
	assert(scene.run.rng.state == failed_rng and scene.run.state.phase == "prepare")
	front.saves.folder = saved_folder
	# A new frame must not silently retry the failed write.
	scene._process(0)
	assert(scene.run.state.phase == "prepare")
	var retry: Button = scene.save_retry_overlay.get_node("Surface/Retry")
	assert(retry != null and retry.is_visible_in_tree())
	retry.pressed.emit()
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible and not scene.save_retry_overlay.visible)
	var retry_rng: int = scene.run.rng.state
	retry.pressed.emit()
	assert(scene.run.rng.state == retry_rng)
	assert(scene.run.state.choices.is_empty() and scene.run.state.refreshes == 0)
	# Continuing a normal wave retains bought recipes and heat and immediately starts.
	heat = scene.run.state.heat
	front.show_menu()
	front.continue_run()
	scene = front.game
	scene.set_process(false)
	assert(scene.run.state.phase == "battle" and scene.run.state.wave == 2)
	assert(not scene.shop_overlay.visible and scene.run.state.heat == heat)
	assert(recipe_id in scene.run.state.recipes and scene.run.state.choices.is_empty())
	scene.speed_button.pressed.emit()
	assert(scene.run.speed == 2)
	scene.settings_button.pressed.emit()
	assert(scene.audio_settings.visible and scene.run.paused)
	var elapsed: float = scene.run.state.elapsed
	scene.run.advance(0.2)
	assert(scene.run.state.elapsed == elapsed)
	scene.speed_button.pressed.emit()
	assert(scene.run.speed == 2)
	scene.audio_settings.confirmed.emit()
	assert(not scene.audio_settings.visible and not scene.run.paused)
	scene.run.advance(0.1)
	assert(scene.run.state.elapsed > elapsed + 0.18)
	# Remaining ordinary waves skip the shop; only three more chapter boundaries stop.
	var boundaries: int = 1
	while scene.run.state.phase != "won":
		var completed: int = scene.run.state.global_wave()
		scene.run.finish_wave()
		scene.rebuild()
		scene._process(0)
		if completed == 40:
			assert(scene.run.state.phase == "won" and not scene.shop_overlay.visible)
		elif completed % 8 == 0:
			boundaries += 1
			assert(scene.run.state.phase == "prepare" and scene.shop_overlay.visible)
			assert(scene.run.state.wave == 1 and scene.run.state.global_wave() == completed + 1)
			scene.shop_surface.get_node("Done").pressed.emit()
		else:
			assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	assert(boundaries == 4 and scene.run.state.metrics.passed == 40)
	front._process(0)
	assert(front.showing_result)
	front.saves.delete_run()
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	print("PASS shop flow: direct new/continue, ordinary waves, four chapter shops, buy/refresh/restore, shop and ordinary save retry, pause/speed, final victory")
	quit()
