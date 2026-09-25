extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.saves.folder = "user://qa_projectile_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.new_run(42)
	game.run.start()
	game.run.director.cursor = game.run.director.events.size()
	var ids: Array[String] = ["bun", "tea", "pepper", "popcorn", "noodles", "bun"]
	for row: int in range(ids.size()):
		var id: String = ids[row]
		game.run.state.cards[id] = 1
		game.run.state.heat = 350
		game.run.state.cooldowns[id] = 0
		game.run.board.place(id, row, 0, false)
		game.run.combat.spawn("gray", row, game.run.data.waves[0])
		game.run.combat.enemies[-1].x = 280.0 if id == "pepper" else 730.0
		game.run.state.units[-1].timer = 100.0
	game.run.combat.step(0.01)
	assert(game.run.combat.projectiles.size() == 6)
	game.run.combat.projectiles[-1].radius = 57.6
	game.run.paused = true
	game.rebuild()
	await snap("board")
	var before: float = game.run.combat.projectiles[0].x
	game.run.advance(0.1)
	assert(game.run.combat.projectiles[0].x == before)
	game.run.paused = false
	game.run.speed = 2.0
	game.run.advance(0.1)
	assert(is_equal_approx(game.run.combat.projectiles[0].x - before, game.run.data.rules.projectile_speed * 0.2))
	game.run.paused = true
	# Space several instances along each lane for an inspectable actual-size atlas.
	game.run.combat.projectiles.clear()
	for row: int in range(ids.size()):
		for x: float in [240.0, 420.0, 600.0]:
			game.run.combat.projectiles.append({"source": ids[row], "row": row, "x": x, "radius": 57.6 if row == 5 else 0.0})
	game.queue_redraw()
	await snap("roster")
	root.size = Vector2i(1600, 900)
	await snap("large")
	game.run.combat.clear()
	assert(game.run.combat.projectiles.is_empty())
	print("PASS projectile sources, pause, 2x speed, clear and native captures")
	game.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_projectiles_" + label + ".png")
