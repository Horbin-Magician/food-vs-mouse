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

func move_pointer(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	root.push_input(event, true)

func run_test() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run.new_run(42)
	for stage: int in range(8):
		scene.run.start()
		scene.run.finish_wave()
	assert(scene.run.shop.is_open())
	scene.run.saves.folder = "user://qa_inspiration_ui_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.run.saves.folder)
	root.add_child(scene)
	scene.set_process(false)
	scene.run.persistence = false
	await process_frame
	# An unspent starting budget still cannot buy a recipe at the first chapter shop.
	assert(scene.run.state.heat == 150)
	for id: String in scene.run.state.choices:
		assert(scene.shop_surface.get_node("Recipe_" + id).disabled)
	assert(not scene.shop_surface.get_node("Done").disabled)
	# The shop's displayed affordability follows the shared heat balance.
	var recipe: String = scene.run.state.choices[0]
	scene.run.state.heat = scene.run.data.rules.recipe_price - 1
	scene.rebuild()
	assert(scene.shop_surface.get_node("Recipe_" + recipe).disabled)
	assert(not scene.shop_refresh.disabled and "热量" in scene.shop_refresh.text)
	scene.run.state.heat = scene.run.data.rules.recipe_price
	scene.rebuild()
	await process_frame
	click(scene.shop_surface.get_node("Recipe_" + recipe).get_global_rect().get_center())
	assert(scene.run.state.recipes.has(recipe) and scene.run.state.heat == 0)
	assert(scene.shop_refresh.disabled and "热量不足" in scene.shop_refresh.tooltip_text)
	scene.run.state.heat = scene.run.data.rules.refresh_cost
	scene.rebuild()
	await process_frame
	click(scene.shop_refresh.get_global_rect().get_center())
	assert(scene.run.state.refreshes == 1 and scene.run.state.heat == 0)

	scene.run.new_run(42)
	scene.run.start()
	assert(scene.run.board.place("pudding", 0, 0, false).is_empty())
	scene.run.combat.produce_heat(scene.run.state.units[0])
	var flame: Dictionary = scene.run.combat.heat_pickups[0]
	flame.age = 1.0
	var pickup: Dictionary = {"uid": scene.run.state.uid(), "row": 0, "x": 48.0, "amount": 1, "age": 1.0, "flight": -1.0}
	scene.run.combat.inspiration_pickups.append(pickup)
	scene._process(0)
	await process_frame
	var pos: Vector2 = scene.inspiration_pickup_view.pickup_position(pickup)
	assert(scene.heat_pickup_view.pickup_at(pos) >= 0, "Fixture overlaps both resource hitboxes")
	scene.selected = "bun"
	scene.run.paused = true
	click(pos)
	assert(pickup.flight < 0 and scene.run.state.collected_inspiration() == 0)
	assert("暂停" in scene.feedback_text and scene.run.state.units.size() == 1)
	assert(flame.flight < 0, "Paused inspiration must not pass through to heat")
	scene.run.paused = false
	scene.shovel = true
	scene.create_debug_panel()
	scene.debug_window.popup_centered()
	await process_frame
	click(pos)
	assert(pickup.flight < 0 and scene.run.state.collected_inspiration() == 0, "Modal blocks pickup")
	scene.debug_window.hide()
	await process_frame
	move_pointer(pos)
	assert(not scene.shovel_cursor_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	click(pos)
	click(pos)
	assert(pickup.flight == 0 and scene.run.state.collected_inspiration() == 1)
	assert(scene.run.state.units.size() == 1 and scene.shovel and scene.selected == "bun")
	assert(flame.flight < 0, "Inspiration has priority over coincident flame")
	scene._process(0)
	assert(scene.inspiration_label.text == "01" and "局外购卡" in scene.inspiration_label.tooltip_text)
	assert("跨关保留" in scene.heat_label.tooltip_text)
	for frame: int in range(12): scene.run.advance(1.0 / 60.0)
	var halfway: Vector2 = scene.inspiration_pickup_view.pickup_position(pickup)
	var target: Vector2 = scene.inspiration_label.get_global_rect().get_center()
	assert(halfway.distance_to(target) < pos.distance_to(target))
	var before: float = pickup.flight
	scene.run.paused = true
	scene.run.advance(0.2)
	assert(pickup.flight == before)
	scene.run.paused = false
	scene.run.speed = 2.0
	for frame: int in range(8): scene.run.advance(1.0 / 60.0)
	assert(scene.run.combat.inspiration_pickups.is_empty())
	assert(scene.run.state.collected_inspiration() == 1)
	# Clicking a spark while it crosses a card cannot start a selection or drag.
	scene.shovel = false
	scene.selected = ""
	var above_card: Dictionary = {"uid": scene.run.state.uid(), "row": 0, "x": 48.0, "amount": 1, "age": 1.0, "flight": 0.2}
	scene.run.combat.inspiration_pickups.append(above_card)
	var over_card: Vector2 = scene.inspiration_pickup_view.pickup_position(above_card)
	assert(scene.cards.get_child(0).get_global_rect().has_point(over_card), "Flight crosses the first card")
	click(over_card)
	assert(scene.selected.is_empty() and scene.drag_card.is_empty())
	assert(scene.run.state.collected_inspiration() == 1)
	var front = load("res://scenes/front_end.gd").new()
	assert(front.run_inspiration(scene.run.state) == scene.earned_inspiration())
	front.free()
	print("PASS inspiration UI: heat shop, real GUI pickup priority, pause, modal, duplicate, shovel, flight, 2x and counters")
	await preload("res://tests/audio_cleanup.gd").release_scene(scene, self)
	quit()
