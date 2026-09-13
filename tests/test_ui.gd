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
	# Shovel requires confirmation during battle, and cancel retains the unit.
	scene.shovel_button.pressed.emit()
	event.position = scene.projection.project(Vector2(48,195))
	scene._unhandled_input(event)
	assert(scene.confirm.visible and scene.run.state.units.size() == 1)
	scene.confirm.hide()
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = "cancel_selection"
	cancel.pressed = true
	scene._unhandled_input(cancel)
	assert(not scene.shovel and scene.selected.is_empty())
	scene.shovel_button.pressed.emit()
	scene._unhandled_input(event)
	scene.confirm.confirmed.emit()
	scene.confirm.hide()
	assert(scene.run.state.units.is_empty())
	for id: String in ArtCatalog.FOOD_IDS: scene.run.state.cards[id] = 1
	scene.rebuild()
	await process_frame
	await process_frame
	assert(scene.cards.get_child_count() == 8)
	assert(scene.cards.position.x >= 190)
	assert(scene.cards.get_global_rect().end.x < scene.shovel_button.position.x)
	assert(scene.cards.get_global_rect().end.y < 112)
	# A visible overlay consumes its entire rectangle, including blank areas.
	scene.run.state.phase = "prepare"
	scene.rebuild()
	scene._process(0)
	scene.shovel = false
	event.position = Vector2(950,380)
	scene._unhandled_input(event)
	assert(scene.move_from == Vector2i(-1,-1))
	scene.panel_open = false
	scene._process(0)
	event.position = scene.projection.project(Vector2(816,624))
	scene._unhandled_input(event)
	assert(scene.move_from == Vector2i(8,6))
	assert(scene.wave_progress() == 0.0)
	scene.run.state.phase = "battle"
	scene.run.director.events.clear()
	scene.run.director.cursor = 0
	assert(scene.wave_progress() == 0.0)
	scene.run.director.events = [{}, {}, {}, {}]
	scene.run.director.cursor = 2
	assert(scene.wave_progress() == 0.5)
	scene.run.paused = true
	assert("暂停" in scene.wave_status())
	scene.run.director.cursor = 4
	assert(scene.wave_progress() == 1.0 and "清理余鼠" in scene.wave_status())
	scene.run.state.phase = "prepare"
	assert(scene.wave_progress() == 0.0)
	scene.run.state.phase = "won"
	assert(scene.wave_progress() == 1.0 and "守卫成功" in scene.wave_status())
	print("PASS UI: placement, pause, animation time, shovel confirmation, cancel, eight-card bounds, overlay input")
	scene.queue_free()
	await process_frame
	quit()
