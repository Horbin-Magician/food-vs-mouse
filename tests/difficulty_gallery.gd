extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_difficulty_gallery_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	front.show_hub("loadout")
	await snap("easy")
	front.hub.find_child("Difficulty_hard",true,false).pressed.emit()
	await snap("hard")
	root.size = Vector2i(1600, 900)
	await snap("large")
	if "--manual" in OS.get_cmdline_user_args(): return
	front.hub.find_child("Launch",true,false).pressed.emit()
	await snap("shop")
	front.game.finish_shopping()
	front.game.run.paused = true
	await snap("battle")
	front.game.run.finish_wave()
	front.game.run.changed.emit()
	await snap("next_shop")
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	print("PASS native difficulty gallery")
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/difficulty_" + label + ".png")
