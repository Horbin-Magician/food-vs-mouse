extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var run := RunController.new()
	run.saves.folder = "user://qa_wave_gallery_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(run.saves.folder) == OK)
	run.new_run(937)
	run.start()
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	scene.run = run
	root.add_child(scene)
	scene.set_process(false)
	run.persistence = false
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		root.size = dimensions
		run.new_run(937)
		run.start()
		assert(run.board.place("pudding", 2, 2, false).is_empty())
		run.combat.produce_heat(run.state.units[0])
		run.director.cursor = run.director.events.size()
		run.director.elapsed = run.director.duration - 1.0
		run.combat.spawn("gray", 2, run.data.waves[0])
		scene.rebuild()
		await snap(scene, "before_%d" % dimensions.x)
		assert(scene.wave_status().contains("剩余 1 秒"))
		run.director.elapsed = run.director.duration
		run.advance(1.0 / 60.0)
		run.advance(0.0)
		await snap(scene, "after_%d" % dimensions.x)
		assert(run.state.wave == 2 and run.state.phase == "battle")
		assert(run.combat.heat_pickups.size() == 1)
		assert(not scene.shop_overlay.visible and run.combat.enemies.is_empty())
		assert(scene.wave_status().contains("剩余 75 秒"))
	print("PASS wave completion gallery: countdown and automatic next wave at two native window sizes")
	await preload("res://tests/audio_cleanup.gd").release_scene(scene, self)
	quit()

func snap(scene: Node, label: String) -> void:
	scene._process(0.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("/tmp/food_wave_" + label + ".png") == OK)
