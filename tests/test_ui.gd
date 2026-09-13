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
	event.position = scene.PANEL_RECT.get_center()
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
	# Readable state and controls stay consistent with business permissions.
	scene.run.state.phase = "prepare"
	scene.run.paused = false
	scene.run.state.coins = 0
	scene.run.state.cooldowns["bun"] = 6.0
	scene.rebuild()
	scene._process(0)
	await process_frame
	assert(not scene.start_button.disabled and scene.pause_button.disabled)
	assert(scene.repair_button.disabled)
	assert(scene.card_status("bun") == "开战后放置")
	assert(not scene.cards.get_child(0).get_node("Cooldown").visible)
	for child: Node in scene.panel.get_children():
		if child is Button: assert(child.disabled)
	assert(scene.panel.get_global_rect().end.x <= scene.PANEL_RECT.end.x)
	assert(scene.panel.get_global_rect().end.y <= scene.PANEL_RECT.end.y)
	scene.run.state.phase = "battle"
	scene.run.paused = true
	scene._process(0)
	assert(scene.card_status("bun") == "已暂停")
	assert(scene.start_button.disabled and not scene.pause_button.disabled)
	assert(scene.pause_button.text == "继续")
	assert(scene.cards.get_child(0).get_node("Cooldown").size.y <= 2)
	scene.run.paused = false
	scene.run.state.cooldowns.clear()
	scene.run.state.heat = 0
	assert(scene.card_status("bun") == "热量不足")
	scene.run.state.heat = 350
	scene.selected = "bun"
	assert("已选中" in scene.card_status("bun"))
	# Modal blank areas must never trigger board placement.
	scene.confirm.popup_centered()
	var unit_count: int = scene.run.state.units.size()
	event.position = scene.projection.project(Vector2(48,48))
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == unit_count)
	scene.confirm.hide()
	scene.run.state.phase = "recipe"
	scene.run.state.choices = ["pressure", "breakfast", "cold_spice"]
	scene.rebuild()
	await process_frame
	await process_frame
	assert(scene.panel.get_global_rect().end.y <= scene.PANEL_RECT.end.y)
	for child: Node in scene.panel.get_children():
		if child is Button:
			for content: Node in child.get_children():
				if content is Control:
					assert(content.position.x + content.size.x <= child.size.x)
					assert(content.position.y + content.size.y <= child.size.y)
	assert(scene.PANEL_RECT.position.x > scene.projection.ORIGIN.x + scene.projection.CANVAS_SIZE.x)
	print("PASS UI: placement, pause, animation time, shovel confirmation, cancel, eight-card bounds, overlay input")
	scene.queue_free()
	await process_frame
	quit()
