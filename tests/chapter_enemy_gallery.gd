extends SceneTree

# Native renderer gallery. Fixtures use actual skill timers and combat signals.
var game: Node2D

func _init() -> void:
	call_deferred("capture")

func reset(chapter: String) -> void:
	game.run.new_run(42)
	game.run.state.chapter_id = chapter
	game.run.state.wave = 8
	game.run.start()
	game.run.director.cursor = game.run.director.events.size()
	game.run.combat.clear()
	game.run.state.units.clear()
	game.run.paused = true
	game.rebuild()
	game._process(0.0)

func place(row: int, col: int) -> Dictionary:
	game.run.state.heat = 9999
	game.run.state.cooldowns.clear()
	assert(game.run.board.place("toast", row, col, false).is_empty())
	var unit: Dictionary = game.run.board.at(row, col)
	unit.timer = -10000.0
	return unit

func mouse(id: String, row: int, x: float) -> Dictionary:
	var enemy: Dictionary = game.run.combat.spawn(id, row, game.run.data.chapter_waves(game.run.state.chapter_id)[7])
	enemy.x = x
	game.animator.entry(enemy).drop = 0.0
	return enemy

func advance_combat(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(remaining, 1.0 / 60.0)
		game.run.combat.step(delta)
		game.animator.advance(delta, game.run.combat.enemies)
		game.damage_feedback.advance(delta)
		game.status_feedback.advance(delta)
		game.enemy_skill_feedback.advance(delta)
		remaining -= delta

func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.run.saves.folder = "user://qa_chapter_enemy_gallery/"
	DirAccess.make_dir_recursive_absolute(game.run.saves.folder)
	root.add_child(game)
	game.run.persistence = false
	game.set_process(false)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	verify_hover_order()
	var cases: Array = [["kitchen_2", "boss_windwhistle", 8.5], ["kitchen_3", "boss_ironpot", 6.5], ["kitchen_4", "boss_starter", 8.5], ["kitchen_5", "boss_quartermaster", 6.5]]
	for fixture: Array in cases:
		reset(fixture[0])
		for row: int in [2, 3, 4]: place(row, 4)
		var boss: Dictionary = mouse(fixture[1], 3, 480.0)
		advance_combat(fixture[2])
		assert(boss.ability_phase == "windup", fixture[1])
		for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(1600,900)]:
			root.size = dimensions
			await snap(fixture[1] + "_warning_%d" % dimensions.x)
		game.pointer = game.projection.foot(boss.x, boss.row) - Vector2(0, 28)
		game.update_inspector()
		await snap(fixture[1] + "_inspect")
		assert(game.run.data.enemies[boss.id].story in game.inspect.text)
		assert("破绽期间承伤 +" in game.inspect.text)
		game.pointer = Vector2(40, 300)
		game.update_inspector()
		if boss.id == "boss_ironpot":
			game.run.combat.damage_enemy(boss, 400.0, "bun")
			assert(boss.shell_broken)
		else:
			advance_combat(boss.ability_remaining + 0.1)
		await snap(fixture[1] + "_action")
		if boss.id == "boss_ironpot":
			# Let the damage flash expire before inspecting the actual unarmored art.
			advance_combat(0.4)
			await snap("boss_ironpot_unarmored_recovery")
			advance_combat(boss.ability_remaining + game.run.data.enemies.boss_ironpot.skills.interval + 0.3)
			assert(boss.shell_broken and boss.ability_phase == "windup")
			await snap("boss_ironpot_unarmored_skill")
			advance_combat(boss.ability_remaining + 0.1)
			await snap("boss_ironpot_unarmored_impact")
		var warning: Array = game.run.combat.abilities.telegraphs.duplicate(true)
		var clock: float = game.run.combat.abilities.clock
		game._process(0.3)
		assert(game.run.combat.abilities.clock == clock and game.run.combat.abilities.telegraphs == warning)
		game.run.combat.damage_enemy(boss, 999999.0, "bun")
		assert(game.run.combat.abilities.telegraphs.is_empty())
		if boss.id == "boss_starter": assert(game.run.combat.abilities.ground_effects.is_empty())
		await snap(fixture[1] + "_defeated")
	if "--boss-only" in OS.get_cmdline_user_args():
		print("PASS chapter boss gallery: four independent bosses, two sizes, warnings, inspect, pause and death cleanup")
		game.queue_free()
		await process_frame
		quit()
		return
	reset("kitchen_2")
	var roster: Array[String] = ["gray", "runner", "lid", "flour", "boss", "spoon_skater", "towel_scout", "rivet_guard", "tong_breaker", "vinegar_spitter", "dough_rat", "ration_keeper", "skewer_lancer", "spoon_captain", "rivet_foreman", "vinegar_cellarer", "skewer_marshal", "boss_windwhistle", "boss_ironpot", "boss_starter", "boss_quartermaster"]
	for index: int in range(roster.size()): mouse(roster[index], index % 7, 240.0 + float(index / 7) * 240.0)
	root.size = Vector2i(1280,720)
	await snap("roster_comparison_1280")
	root.size = Vector2i(1600,900)
	await snap("roster_comparison_1600")
	reset("kitchen_4")
	for row: int in range(7): place(row, 4)
	mouse("vinegar_spitter", 0, 650.0)
	mouse("vinegar_cellarer", 6, 650.0)
	mouse("dough_rat", 1, 750.0)
	mouse("tong_breaker", 2, 480.0)
	mouse("spoon_captain", 5, 850.0)
	mouse("ration_keeper", 4, 730.0)
	mouse("skewer_lancer", 4, 650.0)
	advance_combat(8.5)
	assert(not game.run.combat.abilities.telegraphs.is_empty())
	root.size = Vector2i(1280,720)
	await snap("mixed_warnings_1280")
	advance_combat(2.0)
	await snap("mixed_ground_1280")
	root.size = Vector2i(1600,900)
	await snap("mixed_ground_1600")
	game.run.paused = false
	game.run.speed = 2.0
	var before: float = game.run.combat.abilities.clock
	game._process(0.1)
	assert(is_equal_approx(game.run.combat.abilities.clock - before, 0.2))
	game.run.paused = true
	print("PASS chapter enemy gallery: four bosses, two sizes, actual warnings/ground/shields, inspect, pause, 2x, death cleanup")
	if "--interactive" in OS.get_cmdline_user_args():
		root.title = "鼠群重设 · 原生验收"
		root.size = Vector2i(1280, 720)
		game.set_process(true)
		game.set_process_input(true)
		game.set_process_unhandled_input(true)
		return
	game.queue_free()
	await process_frame
	quit()

func verify_hover_order() -> void:
	reset("kitchen_2")
	mouse("spoon_skater", 3, 480.0)
	var front: Dictionary = mouse("towel_scout", 3, 480.0)
	game.pointer = game.projection.foot(front.x, front.row) - Vector2(0, 28)
	assert(game.hovered_enemy().uid == front.uid)
	reset("kitchen_2")
	var lower: Dictionary = mouse("boss_windwhistle", 4, 480.0)
	var upper: Dictionary = mouse("boss_ironpot", 3, 480.0)
	game.pointer = game.projection.foot(upper.x, upper.row) + Vector2(0, 6)
	assert(game.hovered_enemy().uid == lower.uid)
	var guard: Dictionary = mouse("rivet_guard", 0, 480.0)
	var description: String = game.enemy_description(guard)
	assert("减伤 8" in description and "卸壳后速度 13" in description)
	game.pointer = Vector2(40, 300)

func snap(label: String) -> void:
	var fixture_pointer: Vector2 = game.pointer
	game.update_inspector()
	game.queue_redraw()
	await process_frame
	game.pointer = fixture_pointer
	game.update_inspector()
	await process_frame
	await RenderingServer.frame_post_draw
	if game.inspect.visible:
		assert(game.inspect.position.y >= 0.0 and game.inspect.position.y + game.inspect.size.y <= 720.0)
	root.get_texture().get_image().save_png("/tmp/food_chapter_enemy_" + label + ".png")
