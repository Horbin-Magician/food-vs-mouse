extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var chapter_id: String = "kitchen_2"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--chapter="): chapter_id = argument.trim_prefix("--chapter=")
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(42)
	game.run.saves.folder = "user://qa_chapter_boss_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	game.run.state.chapter_id = chapter_id
	root.add_child(game)
	game.run.persistence = false
	game.set_process(false)
	game.run.state.wave = 8
	game.run.start()
	game.run.combat.spawn("boss", 3, game.run.data.chapter_waves(chapter_id)[7])
	var boss: Dictionary = game.run.combat.enemies[0]
	boss.x = 690
	game.run.combat.request_summons(game.run.combat.boss_configuration().normal_id, boss)
	game.run.combat.step(0.5)
	game.run.paused = true
	game.rebuild()
	game._process(0.0)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		await snap(chapter_id + "_warning_%d" % dimensions.x)
	game.run.combat.step(game.run.combat.boss_configuration().warning_seconds - 0.5)
	assert(game.run.combat.enemies.size() == 3 and game.run.combat.warning_summons.is_empty())
	for enemy: Dictionary in game.run.combat.enemies:
		if enemy.id != "boss": enemy.x = 770
	game.rebuild()
	game._process(0.0)
	await snap(chapter_id + "_arrived_1600")
	game.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS chapter boss gallery: two-size side-lane telegraph and actual arrivals")
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/kitchen_boss_"+label+".png")
