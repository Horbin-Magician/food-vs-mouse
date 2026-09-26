extends SceneTree
func _init() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(42)
	game.run.saves.folder = "user://qa_wave_preview/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.state.wave = 7
	game.run.start()
	game.run.paused = true
	game.run.director.advance(14.0)
	assert(game.run.director.warning_rows().size() == 3)
	game.rebuild()
	await snap("warnings")
	var events: Array = game.run.director.advance(9)
	for event: Dictionary in events:
		game.run.combat.spawn(event.id, event.row, game.run.data.waves[6])
		game.run.combat.enemies[-1].x = 750 - (game.run.director.elapsed - event.time) * game.run.data.enemies[event.id].stats.speed
	game.rebuild()
	await snap("formation")
	root.size = Vector2i(1600,900)
	await snap("large")
	print("PASS native wave warning and formation preview")
	game.queue_free()
	await process_frame
	quit()
func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/wave_" + label + ".png")
