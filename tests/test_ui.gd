extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.run.persistence = false
	scene.run.new_run(25)
	scene.run.start()
	scene.selected = "bun"
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = scene.projection.project(Vector2(48,195))
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	assert(scene.run.state.units[0].row == 2 and scene.run.state.units[0].col == 0)
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	scene.run.paused = true
	scene.selected = "pudding"
	event.position = scene.projection.project(Vector2(144,195))
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	var frozen: float = scene.animator.time
	scene._process(0.1)
	assert(scene.animator.time == frozen)
	scene.run.paused = false
	scene.run.speed = 2.0
	var before: float = scene.run.state.elapsed
	scene._process(0.1)
	assert(is_equal_approx(scene.animator.time - frozen, scene.run.state.elapsed - before))
	assert(scene.animator.time - frozen > 0.18)
	print("PASS UI: event coordinates, repeated click, paused placement")
	scene.queue_free()
	await process_frame
	quit()
