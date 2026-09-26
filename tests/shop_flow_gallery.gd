extends SceneTree

var front: Node
var capture_count: int = 0

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	front = load("res://scenes/front_end.tscn").instantiate()
	var folder: String = "user://qa_shop_gallery_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	front.saves.folder = folder
	root.add_child(front)
	front.saves.folder = folder
	front.set_process(false)
	var blocker := FileAccess.open(folder.path_join("blocked"), FileAccess.WRITE)
	blocker.close()
	blocker = null
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		front.show_menu()
		front.start_new()
		var scene: Node = front.game
		scene.set_process(false)
		var run: RunController = scene.run
		assert(run.state.phase == "battle" and not scene.shop_overlay.visible)
		await snap("new_battle_%d" % dimensions.x)
		run.state.heat = 1400
		assert(run.board.place("bun", 2, 1, false).is_empty())
		assert(run.board.place("toast", 2, 5, false).is_empty())
		run.state.units[0].hp *= 0.6
		for wave: int in range(1, 41):
			assert(run.state.phase == "battle" and run.state.global_wave() == wave)
			if wave == 1: front.saves.folder = folder.path_join("blocked") + "/"
			run.finish_wave()
			scene.rebuild()
			scene._process(0)
			if wave == 1:
				assert(run.state.phase == "prepare" and scene.save_retry_overlay.visible and not scene.shop_overlay.visible)
				await snap("ordinary_save_retry_%d" % dimensions.x)
				front.saves.folder = folder
				scene.save_retry_overlay.get_node("Surface/Retry").pressed.emit()
			if wave == 40:
				assert(run.state.phase == "won" and not scene.shop_overlay.visible)
				front._process(0)
				await snap("final_won_%d" % dimensions.x)
			elif wave % 8 == 0:
				assert(run.state.phase == "prepare" and scene.shop_overlay.visible)
				assert(run.state.wave == 1 and run.state.global_wave() == wave + 1)
				await snap("chapter_%d_shop_%d" % [wave / 8 + 1, dimensions.x])
				scene.shop_surface.get_node("Done").pressed.emit()
				assert(run.state.phase == "battle" and not scene.shop_overlay.visible)
			else:
				assert(run.state.phase == "battle" and not scene.shop_overlay.visible)
				if wave == 1: await snap("ordinary_battle_%d" % dimensions.x)
		front.leave_result("menu")
	print("PASS shop gallery: new and ordinary battles, save retry, four chapter shops, final victory; %d native captures" % capture_count)
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	quit()

func snap(label: String) -> void:
	if is_instance_valid(front.game) and not front.showing_result: front.game._process(0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("/tmp/food_flow_" + label + ".png") == OK)
	capture_count += 1
