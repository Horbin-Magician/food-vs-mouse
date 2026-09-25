extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func click(scene: Node, row: int, col: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.projection.project(Vector2(col * 96 + 48, row * 96 + 48))
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/fvm_remove_" + label + ".png")

func run_test() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run.new_run(25)
	root.add_child(scene)
	scene.run.persistence = false
	scene.run.start()
	scene.set_process(false)
	await process_frame
	assert(scene.run.board.place("bun", 3, 4, false).is_empty())
	scene.shovel = true
	scene.run.paused = true
	click(scene, 0, 0)
	assert(scene.feedback_text.is_empty())
	click(scene, 3, 4)
	assert(scene.run.state.units.size() == 1 and scene.shovel_feedback.effects.is_empty())
	scene.run.paused = false
	var heat: float = scene.run.state.heat
	var metrics: Dictionary = scene.run.state.metrics.duplicate(true)
	click(scene, 3, 4)
	assert(scene.run.board.at(3, 4).is_empty() and scene.shovel)
	assert(scene.shovel_feedback.effects.size() == 1 and not scene.placement_modal_visible())
	assert(scene.run.state.heat == heat and scene.run.state.metrics == metrics)
	click(scene, 3, 4)
	click(scene, 0, 0)
	assert(scene.feedback_text.is_empty() and scene.shovel_feedback.effects.size() == 1)
	if "--capture-remove" in OS.get_cmdline_user_args():
		scene.queue_redraw()
		await capture("start")
		scene.shovel_feedback.advance(0.20)
		scene.queue_redraw()
		await capture("middle")
		root.size = Vector2i(1600, 900)
		scene.queue_redraw()
		await capture("large")
		root.size = Vector2i(1280, 720)
	# Replant while the old visual snapshot is still playing.
	scene.run.state.heat = 350
	scene.run.state.cooldowns.clear()
	assert(scene.run.board.place("toast", 3, 4, false).is_empty())
	assert(scene.run.board.place("pudding", 3, 5, false).is_empty())
	click(scene, 3, 4)
	click(scene, 3, 5)
	assert(scene.run.state.units.is_empty() and scene.shovel_feedback.effects.size() == 3)
	scene.run.paused = true
	var age: float = scene.shovel_feedback.effects[-1].age
	scene._process(0.1)
	assert(scene.shovel_feedback.effects[-1].age == age)
	scene.run.paused = false
	scene.run.speed = 2.0
	scene._process(0.1)
	assert(is_equal_approx(scene.shovel_feedback.effects[-1].age, age + 0.2))
	scene.shovel = false
	scene._process(0.12)
	assert(scene.shovel_feedback.effects.is_empty())
	if "--capture-remove" in OS.get_cmdline_user_args():
		scene.queue_redraw()
		await capture("end")
	assert(scene.run.board.place("bun", 2, 2, false).is_empty())
	scene.shovel = true
	click(scene, 2, 2)
	assert(scene.shovel_feedback.effects.size() == 1)
	scene.run.state.phase = "prepare"
	scene.rebuild()
	assert(scene.shovel_feedback.effects.is_empty())
	print("PASS shovel removal: direct, silent empty, atomic, replant, concurrent, pause, speed, cancel, phase cleanup")
	scene.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	quit()
