extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(25)
	game.run.saves.folder = "user://qa_economy_gallery_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.set_process(false)
	game._process(0)
	await snap("shop")
	root.size = Vector2i(1600, 900)
	await snap("shop_large")
	root.size = Vector2i(1280, 720)
	game.run.start()
	for row: int in range(7):
		var id: String = "pudding" if row % 2 == 0 else "bun"
		game.run.state.heat = 350
		game.run.state.cooldowns.clear()
		game.run.board.place(id, row, 0, false)
		if id == "pudding":
			game.run.combat.produce_heat(game.run.state.units[-1])
			game.run.combat.heat_pickups[-1].age = 1.0
		game.run.combat.spawn("gray", row, game.run.data.waves[0])
		game.run.combat.enemies[-1].x = 700
		game.run.combat.inspiration_pickups.append({"uid": game.run.state.uid(), "row": row, "x": 330.0 + row * 30.0, "amount": 1, "age": 1.0, "flight": -1.0})
	game.run.collect_inspiration(game.run.combat.inspiration_pickups[0].uid)
	game.run.combat.inspiration_pickups[0].flight = 0.24
	game.run.state.heat = 125
	game.run.paused = true
	game.rebuild()
	game._process(0)
	await snap("battle")
	root.size = Vector2i(1600, 900)
	await snap("battle_large")
	print("PASS economy gallery: heat recipe shop and inspiration pickup at 1280x720 and 1600x900")
	if "--hold" in OS.get_cmdline_user_args():
		game.set_process(true)
		return
	await preload("res://tests/audio_cleanup.gd").release_scene(game, self)
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_economy_" + label + ".png")
