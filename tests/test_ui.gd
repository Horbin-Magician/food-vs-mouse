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
	# Shovel removes immediately, with no modal; pause still blocks removal.
	scene.shovel_button.pressed.emit()
	assert(scene.shovel and scene.shovel_cursor_active and scene.selected.is_empty())
	scene.run.paused = true
	scene.update_controls()
	assert(not scene.shovel_cursor_active)
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == 1)
	scene.run.paused = false
	scene.update_controls()
	assert(scene.shovel_cursor_active)
	scene.shovel_button.pressed.emit()
	assert(not scene.shovel and not scene.shovel_cursor_active)
	scene.shovel_button.pressed.emit()
	scene.cards.get_child(0).gui_input.emit(event)
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	scene._input(release)
	assert(not scene.shovel and not scene.shovel_cursor_active)
	scene.shovel_button.pressed.emit()
	event.position = scene.projection.project(Vector2(48,195))
	scene._unhandled_input(event)
	assert(scene.run.state.units.is_empty())
	assert(scene.shovel_feedback.effects.size() == 1)
	assert(scene.shovel_cursor_active)
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = "cancel_selection"
	cancel.pressed = true
	scene._unhandled_input(cancel)
	assert(not scene.shovel and scene.selected.is_empty() and not scene.shovel_cursor_active)
	scene.shovel_button.pressed.emit()
	scene._unhandled_input(event)
	assert(scene.run.state.units.is_empty())
	for id: String in ArtCatalog.FOOD_IDS: scene.run.state.cards[id] = 1
	scene.rebuild()
	await process_frame
	await process_frame
	assert(scene.cards.get_child_count() == 8)
	for count: int in [1, 3, 6]:
		scene.run.state.levels["bun"] = count
		scene.rebuild()
		await process_frame
		var card: Button = scene.cards.get_child(0)
		assert(card.get_node("UpgradeStar/Level").text == "+%d" % scene.run.state.level("bun"))
		assert(card.get_node("Cost").text == "100")
		assert(card.get_node("Portrait").get_rect().end.y <= card.get_node("Cost").position.y)
		assert(card.get_node("UpgradeStar").mouse_filter == Control.MOUSE_FILTER_IGNORE)

	assert(scene.cards.position.x >= 190)
	assert(scene.cards.get_global_rect().end.x < scene.shovel_button.position.x)
	assert(scene.cards.get_global_rect().end.y <= 82)
	# A chapter-boundary shop consumes its entire rectangle, including blank areas.
	scene.run.state.chapter_id = "kitchen_2"
	scene.run.state.wave = 1
	scene.run.state.phase = "prepare"
	scene.run.shop.open()
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
	assert(scene.move_from == Vector2i(-1,-1) and scene.shop_overlay.visible)
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
	scene.run.state.heat = 0
	scene.run.state.cooldowns["bun"] = 6.0
	scene.rebuild()
	scene._process(0)
	await process_frame
	assert(not scene.settings_button.disabled)
	assert(not scene.run.board.has_method("repair"))
	assert("选购食谱" in scene.card_status("bun"))
	assert(not scene.cards.get_child(0).get_node("Cooldown").visible)
	for child: Node in scene.panel.get_children():
		if child is Button: assert(child.disabled)
	assert(scene.panel.get_global_rect().end.x <= scene.PANEL_RECT.end.x)
	assert(scene.panel.get_global_rect().end.y <= scene.PANEL_RECT.end.y)
	scene.run.state.phase = "battle"
	scene.run.paused = true
	scene._process(0)
	assert(scene.card_status("bun") == "已暂停")
	assert(not scene.settings_button.disabled)
	assert(scene.settings_button.text == "设置")
	var mask: ColorRect = scene.cards.get_child(0).get_node("Cooldown")
	assert(mask.size == scene.cards.get_child(0).size and mask.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var frozen_ratio: float = mask.material.get_shader_parameter("remaining_ratio")
	scene._process(0.25)
	assert(is_equal_approx(mask.material.get_shader_parameter("remaining_ratio"), frozen_ratio))
	assert(scene.shovel_button.text.is_empty())
	assert(not scene.cards.get_child(0).has_node("Status"))
	scene.run.state.cooldowns["bun"] = 3.5
	scene.update_controls()
	assert(is_equal_approx(mask.material.get_shader_parameter("remaining_ratio"), 0.5))
	assert(mask.material != scene.cards.get_child(1).get_node("Cooldown").material)
	scene.run.state.cooldowns["bun"] = 7.0
	scene.update_controls()
	assert(is_equal_approx(mask.material.get_shader_parameter("remaining_ratio"), 1.0))
	scene.run.state.cooldowns["bun"] = 0.0
	scene.update_controls()
	assert(not mask.visible)
	scene.run.paused = false
	scene.run.state.cooldowns.clear()
	scene.run.state.heat = 0
	assert(scene.card_status("bun") == "热量不足")
	var bun_card: Button = scene.cards.get_child(0)
	for heat: float in [99.0, 100.0, 99.0, 350.0]:
		scene.run.state.heat = heat
		scene.update_controls()
		assert(bun_card.material.get_shader_parameter("unaffordable") == (heat < 100))
		assert(not scene.cards.get_child(1).material.get_shader_parameter("unaffordable"))
	scene.run.state.heat = 99
	scene.run.state.cooldowns["bun"] = 7
	scene.run.paused = true
	scene.update_controls()
	assert(bun_card.material.get_shader_parameter("unaffordable") and mask.visible)
	assert(bun_card.get_node("Portrait").material == bun_card.material)
	assert(bun_card.get_node("UpgradeStar/Level").material == bun_card.material)
	assert(mask.material != bun_card.material)
	scene.run.state.heat = 100
	scene.update_controls()
	assert(not bun_card.material.get_shader_parameter("unaffordable") and mask.visible)
	scene.run.state.heat = 99
	scene.run.state.cooldowns.clear()
	scene.update_controls()
	assert(bun_card.material.get_shader_parameter("unaffordable") and not mask.visible)
	scene.run.paused = false
	scene.run.state.heat = 350
	scene.selected = "bun"
	assert("已选中" in scene.card_status("bun"))
	# Modal blank areas must never trigger board placement.
	scene.create_debug_panel()
	scene.debug_window.popup_centered()
	var unit_count: int = scene.run.state.units.size()
	event.position = scene.projection.project(Vector2(48,48))
	scene._unhandled_input(event)
	assert(scene.run.state.units.size() == unit_count)
	scene.debug_window.hide()
	scene.run.state.phase = "prepare"
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
	assert(is_equal_approx(scene.projection.ORIGIN.x + scene.projection.CANVAS_SIZE.x / 2.0, 640.0))
	# Shop modal: transaction rebuilding, horizontal layout, closing and input isolation.
	scene.run.new_run(25)
	scene.run.state.chapter_id = "kitchen_2"
	scene.run.state.wave = 1
	scene.run.shop.open()
	scene.rebuild()
	scene.set_panel_open(true)
	await process_frame
	await process_frame
	assert(scene.shop_overlay.visible and not scene.panel.visible)
	assert(scene.shop_items.get_child_count() == 0 and scene.run.state.offers.is_empty())
	for id: String in scene.run.state.choices:
		var item: Button = scene.shop_surface.get_node("Recipe_" + id)
		assert(scene.SHOP_RECT.encloses(item.get_global_rect()))
		for content: Control in item.get_children():
			assert(Rect2(Vector2.ZERO,item.size).encloses(content.get_rect()))
	event.position = scene.projection.project(Vector2(48, 48))
	scene._unhandled_input(event)
	assert(scene.move_from == Vector2i(-1, -1))
	var offers: Array = scene.run.state.offers.duplicate(true)
	var rng_state: int = scene.run.rng.state
	scene._input(cancel)
	assert(scene.shop_overlay.visible and scene.run.state.phase == "prepare")
	assert(scene.run.state.offers == offers and scene.run.rng.state == rng_state)
	var heat_before: float = scene.run.state.heat
	assert(not scene.run.shop.buy(0).is_empty() and scene.run.state.heat == heat_before)
	scene.run.state.heat = scene.run.data.rules.recipe_price + 150
	scene.rebuild()
	var recipe_id: String = scene.run.state.choices[0]
	var recipe_button: Button = scene.shop_surface.get_node("Recipe_" + recipe_id)
	assert(scene.SHOP_RECT.encloses(recipe_button.get_global_rect()))
	recipe_button.pressed.emit()
	assert(scene.run.state.heat == 150 and recipe_id in scene.run.state.recipes)
	assert(not scene.shop_surface.has_node("Recipe_" + recipe_id))
	scene.run.state.heat = scene.run.data.rules.refresh_cost * 2 + 50
	scene.rebuild()
	scene.shop_refresh.pressed.emit()
	assert(scene.run.state.heat == scene.run.data.rules.refresh_cost + 50 and scene.run.state.refreshes == 1)
	scene.shop_refresh.pressed.emit()
	assert(scene.run.state.heat == 50 and scene.run.state.refreshes == 2 and scene.shop_refresh.disabled)
	scene.run.state.heat = 0
	scene.rebuild()
	for item: Button in scene.shop_items.get_children(): assert(item.disabled)
	for id: String in ArtCatalog.FOOD_IDS: scene.run.state.cards[id] = 1
	scene.run.shop.generate()
	scene.rebuild()
	for item: Button in scene.shop_items.get_children():
		assert(item.disabled and item.text == "已收集全部美食")
	scene.shop_overlay.gui_input.emit(event)
	assert(scene.shop_overlay.visible and scene.move_from == Vector2i(-1, -1))
	assert(not scene.shop_surface.has_node("Close"))
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(not scene.shop_overlay.visible and scene.run.state.phase == "battle")
	var begin_rng: int = scene.run.rng.state
	scene.finish_shopping()
	assert(scene.run.rng.state == begin_rng)
	scene.set_panel_open(true)
	assert(not scene.shop_overlay.visible)
	scene.shovel_button.pressed.emit()
	assert(scene.shovel_cursor_active)
	scene.run.state.wave = 8
	scene.run.finish_wave()
	scene.rebuild()
	assert(scene.shop_overlay.visible and not scene.shovel_cursor_active)
	scene.shop_surface.get_node("Done").pressed.emit()
	assert(scene.run.state.phase == "battle" and not scene.shop_overlay.visible)
	scene.run.state.phase = "won"
	scene.update_controls()
	assert(not scene.shovel and not scene.shovel_cursor_active)
	print("PASS UI: placement, pause, animation time, shovel cursor lifecycle and direct removal, cancel, eight-card bounds, overlay input")
	await preload("res://tests/audio_cleanup.gd").release_scene(scene, self)
	quit()
