extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(25)
	game.run.saves.folder = "user://qa_battle_art/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.start()
	for id: String in ArtCatalog.FOOD_IDS:
		game.run.state.cards[id] = 1
	for row: int in range(7):
		for col: int in range(2):
			var id: String = ArtCatalog.FOOD_IDS[(row + col) % 8]
			game.run.state.heat = 350
			game.run.state.cooldowns[id] = 0
			game.run.board.place(id, row, col, false)
		game.run.combat.spawn("gray", row, game.run.data.waves[0])
		game.run.combat.enemies[-1].x = 740 if row % 2 else 880
	game.run.state.cooldowns.clear()
	game.run.state.cooldowns["bun"] = 3.5
	game.run.state.heat = 150
	game.run.paused = true
	game.rebuild()
	await snap("default")
	assert(game.cards.get_global_rect().end.x <= 830)
	root.size = Vector2i(1600, 900)
	await snap("large")
	print("PASS battle art: eight cards fit before resources; native two-size capture")
	if "--hold" in OS.get_cmdline_user_args(): return
	game.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_battle_art_" + label + ".png")
