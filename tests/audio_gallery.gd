extends SceneTree

var front: Node

func _init() -> void:
	call_deferred("capture")

func put(id: String, row: int, col: int) -> void:
	var run: RunController = front.game.run
	run.state.cards[id] = 1
	run.state.cooldowns.clear()
	run.state.heat = 9999
	assert(run.board.place(id,row,col,false).is_empty())

func capture() -> void:
	root.size = Vector2i(1280,720)
	front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_audio_gallery_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(front.saves.folder) == OK)
	front.sound.settings_path = front.saves.folder.path_join("audio.cfg")
	front.sound.load_settings()
	front.show_menu()
	await snap("menu")
	front.show_hub("shop")
	await snap("hub")
	front.show_menu()
	front.audio_button.pressed.emit()
	await snap("settings_menu")
	front.audio_settings.hide()
	front.start_new()
	front.game.finish_shopping()
	front.game.run.persistence = false
	front.game.set_process(false)
	for row: int in range(7):
		put("bun",row,1)
		put("toast",row,5)
	put("tea",1,3)
	put("pepper",2,4)
	put("popcorn",3,3)
	put("noodles",4,3)
	put("garlic",5,2)
	put("pudding",0,0)
	put("pudding",6,0)
	var enemies: Array[String] = ["gray","lid","runner","gnawer","flour","drummer","gray"]
	for row: int in range(7):
		front.game.run.combat.spawn(enemies[row],row,front.game.run.data.waves[0])
		front.game.run.combat.enemies[-1].x = 700 + row * 22
	front.game.run.state.heat = 1000
	front.game.run.state.cooldowns.clear()
	front.game.rebuild()
	front.game.animator.bind(front.game.run,front.game.projection)
	front.game.animator.advance(1,front.game.run.combat.enemies)
	await snap("battle")
	front.audio_button.pressed.emit()
	await snap("settings_battle")
	root.size = Vector2i(1600,900)
	await snap("large_settings")
	front.audio_settings.hide()
	root.size = Vector2i(1280,720)
	front.game.set_process(true)
	print("PASS audio gallery: six native captures in /tmp/food_audio_*.png")
	if "--manual" in OS.get_cmdline_user_args():
		print("Audio manual fixture ready: isolated saves, all eight foods, normal battle music")
		return
	front.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/food_audio_" + label + ".png") == OK)
