extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var screen = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(screen)
	screen.saves.folder = "user://qa_screens_gallery/"
	DirAccess.make_dir_recursive_absolute(screen.saves.folder)
	screen.saves.delete_run()
	screen.show_menu()
	await snap("menu")
	screen.start_new()
	screen.game.run.state.wave = 8
	screen.game.run.start()
	screen.game.run.state.elapsed = 847
	screen.game.run.state.metrics.kills = 204
	screen.game.run.finish_wave()
	screen._process(0)
	await snap("won")
	screen.leave_result("new")
	screen.game.run.start()
	screen.game.run.state.pantry = 0
	screen.game.run.advance(0.1)
	screen._process(0)
	await snap("lost")
	root.size = Vector2i(1600, 900)
	await snap("lost_large")
	screen.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_screens_" + label + ".png")
