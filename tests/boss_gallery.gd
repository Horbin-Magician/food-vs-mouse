extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(42)
	game.run.saves.folder = "user://qa_boss_difficulty/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.state.wave = 8
	game.run.start()
	game.run.director.cursor = game.run.director.events.size()
	game.run.combat.spawn("boss", RunState.CENTER_ROW, game.run.data.waves[7])
	var boss: Dictionary = game.run.combat.enemies[0]
	boss.x = 650
	for i: int in range(601): game.run.combat.step(1.0 / 60.0)
	assert(game.run.combat.enemies.size() == 3)
	game.run.combat.damage_enemy(boss, 1301, "bun")
	for i: int in range(481): game.run.combat.step(1.0 / 60.0)
	assert(game.run.combat.enemies.size() == 7)
	game.run.paused = true
	game.rebuild()
	await snap("default")
	root.size = Vector2i(1600,900)
	await snap("large")
	print("PASS boss gallery: normal and rage summons rendered at two sizes")
	game.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_boss_" + label + ".png")
