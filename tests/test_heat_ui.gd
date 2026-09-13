extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func click(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run_test() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.run.persistence = false
	scene.run.new_run(42)
	scene.run.start()
	scene.run.board.place("pudding", 0, 0, false)
	scene.run.combat.produce_heat(scene.run.state.units[0])
	var pickup: Dictionary = scene.run.combat.heat_pickups[0]
	pickup.age = 1.0
	scene._process(0)
	await process_frame
	await process_frame
	var pos: Vector2 = scene.heat_pickup_view.pickup_position(pickup)
	assert(pos.y > 100 and pos.x > 190)
	scene.selected = "bun"
	scene.run.paused = true
	click(pos)
	assert(pickup.flight < 0 and scene.run.state.heat == 100)
	assert("暂停" in scene.feedback_text and scene.run.state.units.size() == 1)
	scene.run.paused = false
	scene.shovel = true
	scene.restart.popup_centered()
	await process_frame
	click(pos)
	assert(pickup.flight < 0, "modal blocks pickup")
	scene.restart.hide()
	await process_frame
	click(pos)
	click(pos)
	assert(pickup.flight == 0 and scene.run.state.heat == 100)
	assert(not scene.confirm.visible and scene.run.state.units.size() == 1 and scene.shovel)
	for frame: int in range(13): scene.run.advance(1.0 / 60.0)
	var halfway: Vector2 = scene.heat_pickup_view.pickup_position(pickup)
	assert(halfway.distance_to(scene.heat_label.get_global_rect().get_center()) < pos.distance_to(scene.heat_label.get_global_rect().get_center()))
	assert(scene.run.state.heat < 101)
	for frame: int in range(14): scene.run.advance(1.0 / 60.0)
	assert(scene.run.combat.heat_pickups.is_empty())
	assert(absf(scene.run.state.heat - 115.9) < 0.001)
	scene._process(0)
	assert(scene.heat_label.text == "115" and "每秒恢复 2" in scene.heat_label.tooltip_text)
	print("PASS heat UI: real GUI events, pause, modal, selected card, shovel, duplicate, flight target and counter")
	scene.queue_free()
	await process_frame
	quit()
