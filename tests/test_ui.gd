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
	event.position = Vector2(168,345)
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	assert(scene.run.state.units[0].row == 2 and scene.run.state.units[0].col == 0)
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	scene.run.paused = true
	scene.selected = "pudding"
	event.position = Vector2(264,345)
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	print("PASS UI: event coordinates, repeated click, paused placement")
	scene.queue_free()
	await process_frame
	quit()
