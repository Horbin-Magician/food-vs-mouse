extends SceneTree

var scene: Node

func _init() -> void:
	call_deferred("run_test")

func mouse(pos: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	root.push_input(event, true)

func motion(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func cell(col: int, row: int) -> Vector2:
	return scene.projection.project(Vector2(col * 96 + 48, row * 96 + 48))

func begin(id: String, target: Vector2) -> void:
	await process_frame
	await process_frame
	var index: int = scene.run.state.cards.keys().find(id)
	var source: Vector2 = scene.cards.get_child(index).get_global_rect().get_center()
	motion(source)
	mouse(source, true)
	assert(scene.drag_card == id and not scene.drag_active)
	motion(target)
	assert(scene.drag_active)

func run_test() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.run.persistence = false
	scene.run.new_run(25)
	scene.run.start()
	await begin("bun", cell(0, 0))
	assert(scene.run.state.units.is_empty() and scene.run.state.heat == 150)
	for i: int in range(10): assert(scene.drag_placement_error().is_empty())
	assert(scene.run.state.cooldowns.is_empty())
	mouse(cell(0, 0), false)
	assert(scene.run.state.units.size() == 1 and scene.run.state.heat == 50)
	assert(scene.selected.is_empty() and not scene.drag_active)
	mouse(cell(0, 0), false)
	assert(scene.run.state.units.size() == 1 and scene.run.state.heat == 50)
	# Read-only preview and release use the same live validation.
	scene.run.state.heat = 350
	await begin("bun", cell(1, 0))
	assert(scene.drag_placement_error() == "卡牌冷却中")
	mouse(cell(1, 0), false)
	assert(scene.run.state.heat == 350 and scene.run.state.units.size() == 1)
	scene.run.state.cooldowns.clear()
	await begin("bun", cell(0, 0))
	assert(scene.drag_placement_error() == "格子已占用")
	mouse(cell(0, 0), false)
	scene.run.state.heat = 0
	await begin("bun", cell(1, 0))
	assert(scene.drag_placement_error() == "热量不足")
	mouse(cell(1, 0), false)
	assert(scene.run.state.units.size() == 1 and scene.run.state.heat == 0)
	scene.run.state.heat = 350
	# Revalidate after a valid preview if resources change before release.
	await begin("bun", cell(1, 0))
	assert(scene.drag_placement_error().is_empty())
	scene.run.state.heat = 0
	mouse(cell(1, 0), false)
	assert(scene.run.state.units.size() == 1)
	scene.run.state.heat = 350
	# Outside and UI releases cancel without triggering their buttons.
	await begin("bun", Vector2(50, 300))
	mouse(Vector2(50, 300), false)
	assert(scene.selected.is_empty() and scene.run.state.heat == 350)
	await begin("bun", scene.pause_button.get_global_rect().get_center())
	mouse(scene.pause_button.get_global_rect().get_center(), false)
	assert(not scene.run.paused and scene.run.state.units.size() == 1)
	await begin("bun", cell(1, 0))
	mouse(cell(1, 0), true, MOUSE_BUTTON_RIGHT)
	mouse(cell(1, 0), false, MOUSE_BUTTON_RIGHT)
	mouse(cell(1, 0), false)
	assert(scene.drag_card.is_empty() and scene.run.state.units.size() == 1)
	await begin("bun", cell(1, 0))
	var cancel := InputEventKey.new()
	cancel.physical_keycode = KEY_ESCAPE
	cancel.pressed = true
	root.push_input(cancel, true)
	mouse(cell(1, 0), false)
	assert(scene.selected.is_empty() and scene.run.state.units.size() == 1)
	await begin("bun", cell(1, 0))
	root.focus_exited.emit()
	mouse(cell(1, 0), false)
	assert(scene.drag_card.is_empty() and scene.run.state.units.size() == 1)
	await begin("bun", cell(1, 0))
	scene.run.paused = true
	scene._process(0)
	assert(not scene.drag_active)
	mouse(cell(1, 0), false)
	await begin("bun", cell(1, 0))
	assert("暂停" in scene.drag_placement_error())
	mouse(cell(1, 0), false)
	assert(scene.run.state.units.size() == 1 and scene.run.state.heat == 350)
	scene.run.paused = false
	await begin("bun", cell(1, 0))
	scene.run.state.phase = "recipe"
	scene.rebuild()
	mouse(cell(1, 0), false)
	assert(scene.drag_card.is_empty() and scene.run.state.units.size() == 1)
	scene.run.state.phase = "prepare"
	scene.rebuild()
	scene.set_panel_open(false)
	await begin("bun", cell(1, 0))
	assert("战斗" in scene.drag_placement_error())
	mouse(cell(1, 0), false)
	assert(scene.run.state.units.size() == 1 and scene.move_from == Vector2i(-1, -1))
	await begin("bun", cell(1, 0))
	scene.set_panel_open(true)
	assert(scene.drag_card.is_empty())
	mouse(cell(1, 0), false)
	scene.set_panel_open(false)
	scene.run.start()
	# Keep the existing click-to-select interaction with sub-threshold movement.
	await process_frame
	await process_frame
	var source: Vector2 = scene.cards.get_child(0).get_global_rect().get_center()
	mouse(source, true)
	motion(source + Vector2(2, 0))
	mouse(source + Vector2(2, 0), false)
	assert(scene.selected == "bun" and scene.drag_card.is_empty())
	mouse(cell(8, 6), true)
	mouse(cell(8, 6), false)
	assert(scene.run.board.at(6, 8).id == "bun")
	# A sixth pudding is legal in both preview and actual placement.
	for col: int in range(5):
		scene.run.state.cooldowns.clear()
		scene.run.state.heat = 350
		assert(scene.run.board.place("pudding", 2, col, false).is_empty())
	scene.run.state.cooldowns.clear()
	scene.run.state.heat = 350
	await begin("pudding", cell(5, 2))
	assert(scene.drag_placement_error().is_empty())
	mouse(cell(5, 2), false)
	assert(scene.run.state.units.size() == 8 and scene.run.state.heat == 300)
	await begin("bun", cell(1, 0))
	scene.restart.popup_centered()
	scene._process(0)
	assert(scene.drag_card.is_empty() and not scene.drag_preview.visible)
	scene.restart.hide()
	mouse(cell(1, 0), false)
	print("PASS drag: GUI events, atomic placement, live validation, bounds, cancel, focus, pause, phase, modal, click fallback")
	scene.queue_free()
	await process_frame
	quit()
