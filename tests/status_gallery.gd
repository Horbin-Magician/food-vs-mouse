extends SceneTree

var game: Node2D
var boss: Dictionary

func _init() -> void:
	call_deferred("capture")

func put(id: String, row: int, col: int) -> Dictionary:
	game.run.state.cards[id] = 1
	game.run.state.heat = 9999
	game.run.state.cooldowns.clear()
	game.run.board.place(id, row, col, false)
	return game.run.state.units[-1]

func mouse(id: String, row: int, x: float) -> Dictionary:
	game.run.combat.spawn(id, row, game.run.data.waves[7])
	game.run.combat.enemies[-1].x = x
	return game.run.combat.enemies[-1]

func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.run.new_run(42)
	game.run.saves.folder = "user://qa_status_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.run.state.wave = 8
	game.run.start()
	game.run.director.cursor = game.run.director.events.size()
	game.run.paused = true
	game.run.state.recipes.assign(["breakfast", "crust", "pressure", "burn", "cold_spice", "wide"])
	put("garlic", 1, 1)
	var bun: Dictionary = put("bun", 1, 2)
	bun.attacks = 3
	put("pudding", 1, 3)
	put("toast", 1, 5)
	mouse("lid", 1, 720)
	put("garlic", 3, 1)
	var pepper: Dictionary = put("pepper", 3, 2)
	put("pudding", 3, 3)
	put("tea", 3, 5)
	var chilled: Dictionary = mouse("gray", 3, 720)
	game.run.combat.hit({"source": "tea", "damage": 1.0, "radius": 0.0}, chilled)
	game.run.combat.hit({"source": "pepper", "damage": 1.0, "radius": 0.0}, chilled)
	var flour: Dictionary = mouse("flour", 3, 240)
	game.run.combat.damage_enemy(flour, 10000, "bun")
	put("popcorn", 5, 1)
	put("noodles", 5, 3)
	mouse("drummer", 5, 590)
	mouse("runner", 5, 710)
	boss = mouse("boss", 6, 520)
	game.rebuild()
	game.animator.bind(game.run, game.projection)
	game.animator.advance(1, game.run.combat.enemies)
	game.status_feedback.advance(1.2)
	await snap("statuses")
	# Use business events, including actual randomly selected summon rows.
	boss.summon = 9.99
	game.run.combat.step(0.02)
	game.status_feedback.advance(0)
	await snap("summon_start")
	game.status_feedback.advance(0.22)
	await snap("summon_mid")
	var age: float = game.status_feedback.effects[-1].age
	await process_frame
	assert(game.status_feedback.effects[-1].age == age)
	game.status_feedback.advance(1.2)
	game.run.combat.damage_enemy(boss, 1301, "bun")
	game.status_feedback.advance(0.18)
	await snap("rage")
	root.size = Vector2i(1600, 900)
	await snap("large")
	game.status_feedback.advance(1.2)
	game.run.combat.hit({"source": "bun", "damage": 1.0, "radius": 72.0}, chilled)
	game.run.combat.hit({"source": "popcorn", "damage": 1.0, "radius": 84.0}, game.run.combat.enemies[0])
	game.run.combat.produce_heat(game.run.board.at(1, 3))
	var cloud: Dictionary = mouse("flour", pepper.row, 240)
	game.run.combat.damage_enemy(cloud, 10000, "bun")
	game.status_feedback.advance(0.18)
	await snap("skills")
	game.set_process(false)
	game.run.paused = false
	game.run.speed = 2
	var before: float = game.status_feedback.time
	game._process(0.05)
	assert(is_equal_approx(game.status_feedback.time - before, 0.1))
	game.run.paused = true
	game.set_process(true)
	game.status_feedback.advance(1.2)
	await snap("clear")
	# Render every effect through its fade tail, including subpixel sparks.
	for id: String in StatusFeedback.DURATIONS:
		game.status_feedback.on_skill(id, boss, [chilled])
	game.status_feedback.effects[0].origin = Vector2(1220, 650)
	for frame: int in range(70):
		game.status_feedback.advance(1.0 / 60.0)
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	assert(game.status_feedback.effects.is_empty())
	if not "--status-live" in OS.get_cmdline_user_args():
		while game.run.combat.enemies.size() < 46:
			var index: int = game.run.combat.enemies.size()
			var extra: Dictionary = mouse("lid", index % 7, 790 - (index / 7) * 32)
			extra.slow_time = 3
			extra.burn_time = 3
		game.animator.advance(1, game.run.combat.enemies)
		game.status_feedback.advance(0)
		assert(game.status_feedback.dense)
		await snap("dense")
		game.run.combat.enemies.resize(44)
		game.status_feedback.advance(0)
		assert(not game.status_feedback.dense)
		await snap("restored")
	print("PASS status gallery: native status layers, casts, impact effects, pause, 2x and two sizes")
	if "--status-live" in OS.get_cmdline_user_args(): return
	game.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_status_" + label + ".png")
