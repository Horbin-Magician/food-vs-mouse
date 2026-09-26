extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(42)
	game.run.saves.folder = "user://qa_difficulty_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	await snap("easy")
	game.shop_surface.get_node("Difficulty_hard").pressed.emit()
	await snap("hard")
	root.size = Vector2i(1600, 900)
	await snap("large")
	if "--manual" in OS.get_cmdline_user_args(): return
	game.finish_shopping()
	game.run.paused = true
	await snap("battle")
	game.queue_free()
	await process_frame
	print("PASS native difficulty gallery")
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/difficulty_" + label + ".png")
