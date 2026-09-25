extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.saves.folder = "user://qa_damage_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.new_run(42)
	game.run.start()
	game.run.paused = true
	var foods: Array[String] = ["bun", "toast", "pudding", "tea", "pepper", "popcorn", "noodles", "garlic"]
	var mice: Array[String] = ["gray", "runner", "lid", "gnawer", "drummer", "flour", "elite", "boss"]
	for i: int in range(8):
		game.run.state.cards[foods[i]] = 1
		game.run.state.heat = 350
		game.run.state.cooldowns.clear()
		game.run.board.place(foods[i], i % 4 + 1, 1 + (i / 4) * 4, false)
		game.run.combat.spawn(mice[i], i % 4 + 1, game.run.data.waves[0])
		game.run.combat.enemies[-1].x = 330.0 + (i / 4) * 384.0
	game.rebuild()
	await snap("before")
	for unit: Dictionary in game.run.state.units:
		game.run.combat.damage_unit(unit, 20.0)
	for enemy: Dictionary in game.run.combat.enemies:
		game.run.combat.damage_enemy(enemy, 24.0, "bun")
	await snap("hit")
	var age: float = game.damage_feedback.numbers[0].age
	await process_frame
	assert(game.damage_feedback.numbers[0].age == age)
	game.run.combat.damage_enemy(game.run.combat.enemies[0], 6.0, "pepper", false)
	game.run.combat.damage_unit(game.run.state.units[1], 10000.0)
	await snap("lethal")
	game.damage_feedback.advance(0.09)
	await snap("fade")
	root.size = Vector2i(1600, 900)
	await snap("large")
	game.run.paused = false
	game.run.speed = 2.0
	game.set_process(false)
	var before: float = game.damage_feedback.numbers[0].age
	game._process(0.05)
	assert(is_equal_approx(game.damage_feedback.numbers[0].age - before, 0.1))
	game.run.paused = true
	game.damage_feedback.advance(1.0)
	assert(game.damage_feedback.numbers.is_empty() and game.damage_feedback.flashes.is_empty())
	await snap("clear")
	print("PASS damage gallery all actors, lethal, native shader, pause, 2x and expiry")
	game.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_damage_" + label + ".png")
