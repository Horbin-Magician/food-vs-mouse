extends SceneTree

var front: Node

func _init() -> void:
	call_deferred("check")

func frames() -> void:
	if is_instance_valid(front) and is_instance_valid(front.game) and not front.showing_result:
		front.game._process(0)
	await process_frame
	await process_frame
	if is_instance_valid(front) and is_instance_valid(front.game) and not front.showing_result:
		front.game._process(0)

func escape(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)

func click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
		root.push_input(event, true)

func confirm_leave() -> void:
	front.audio_settings.leave_confirmation.confirmed.emit()
	await frames()

func check() -> void:
	root.size = Vector2i(1280, 720)
	front = load("res://scenes/front_end.tscn").instantiate()
	front.saves.folder = "user://qa_settings_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(front.saves.folder) == OK)
	var folder: String = front.saves.folder
	root.add_child(front)
	# The generic --qa-test entry flag must not replace this fixture's unique storage.
	front.saves.folder = folder
	front.sound.settings_path = folder.path_join("audio.cfg")
	front.sound.load_settings()
	front.audio_settings.setup(front.sound)
	front.show_menu()
	await frames()
	assert(front.audio_button.text == "设置")
	assert(InputMap.has_action("open_settings"))
	for event: InputEvent in InputMap.action_get_events("cancel_selection"):
		assert(not event is InputEventKey, "Esc must only open settings")
	# Main-menu and card-hub entry preserve their context.
	escape()
	await frames()
	assert(front.audio_settings.visible and not front.audio_settings.menu_button.visible)
	assert(front.audio_settings.quit_button.visible and front.audio_settings.get_ok_button().text == "返回")
	escape(true)
	await frames()
	assert(front.audio_settings.visible, "holding Esc must not close the new dialog")
	escape()
	await frames()
	assert(not front.audio_settings.visible)
	front.show_hub("shop")
	escape()
	await frames()
	assert(front.audio_settings.visible and front.audio_settings.menu_button.visible)
	front.audio_settings.menu_button.pressed.emit()
	await frames()
	assert(not front.audio_settings.visible and front.page.visible and front.game == null)
	front.start_new()
	front.game.set_process(false)
	await frames()
	var scene: Node = front.game
	var run: RunController = scene.run
	assert(scene.speed_button.position == Vector2(34, 47))
	assert(scene.speed_button.size == Vector2(124, 28))
	assert(scene.speed_button.position.y >= scene.heat_label.get_rect().end.y)
	assert(scene.settings_button.position == Vector2(1104, 22))
	assert(scene.settings_button.get_rect().end.x <= scene.shovel_button.position.x)
	assert(scene.cards.get_global_rect().end.x < scene.settings_button.position.x)
	# Settings above the mandatory shop must preserve transactions and random state.
	var choices: Array = run.state.choices.duplicate()
	var rng_state: int = run.rng.state
	var heat: float = run.state.heat
	escape()
	await frames()
	assert(front.audio_settings.visible and scene.shop_overlay.visible and not run.paused)
	click(scene.speed_button.get_global_rect().get_center())
	assert(run.speed == 1.0)
	await frames()
	escape()
	await frames()
	assert(not front.audio_settings.visible and scene.shop_overlay.visible, "closed=%s shop=%s phase=%s" % [not front.audio_settings.visible, scene.shop_overlay.visible, run.state.phase])
	assert(run.state.choices == choices and run.rng.state == rng_state and run.state.heat == heat)
	run.state.heat = 700
	scene.finish_shopping()
	await frames()
	var snapshot: Dictionary = front.saves.load_run(front.data).duplicate(true)
	assert(snapshot.phase == "prepare" and run.state.phase == "battle")
	click(scene.speed_button.get_global_rect().get_center())
	assert(run.speed == 2.0, "speed=%s disabled=%s phase=%s modal=%s" % [run.speed, scene.speed_button.disabled, run.state.phase, scene.placement_modal_visible()])
	# Right click cancels the shovel; Esc clears every pending board operation.
	click(scene.shovel_button.get_global_rect().get_center())
	assert(scene.shovel and scene.shovel_cursor_active)
	click(Vector2(640, 400), MOUSE_BUTTON_RIGHT)
	assert(not scene.shovel and not scene.audio_settings.visible and not run.paused)
	click(scene.shovel_button.get_global_rect().get_center())
	scene.move_from = Vector2i(1, 1)
	escape()
	await frames()
	assert(front.audio_settings.visible and run.paused and front.sound.game_paused)
	assert(not scene.shovel and not scene.shovel_cursor_active and scene.move_from == Vector2i(-1, -1))
	assert(scene.selected.is_empty() and scene.drag_card.is_empty())
	var elapsed: float = run.state.elapsed
	var animation_time: float = scene.animator.time
	scene._process(0.25)
	assert(run.state.elapsed == elapsed and scene.animator.time == animation_time)
	click(scene.speed_button.get_global_rect().get_center())
	assert(run.speed == 2.0, "modal must block underlying speed button")
	front.audio_settings.quit_button.pressed.emit()
	await frames()
	assert(front.audio_settings.leave_confirmation.visible and run.paused)
	assert("开战前" in front.audio_settings.leave_confirmation.dialog_text)
	escape()
	await frames()
	assert(not front.audio_settings.leave_confirmation.visible and front.audio_settings.visible and run.paused)
	escape()
	await frames()
	assert(not front.audio_settings.visible and not run.paused and run.speed == 2.0)
	# Cancel restores an existing pause, while the primary action explicitly resumes.
	run.paused = true
	front.open_settings()
	front.audio_settings.hide()
	assert(run.paused)
	front.open_settings()
	assert(front.audio_settings.get_ok_button().text == "继续游戏")
	front.audio_settings.confirmed.emit()
	assert(not front.audio_settings.visible and not run.paused)
	click(scene.settings_button.get_global_rect().get_center())
	await frames()
	assert(front.audio_settings.visible and run.paused)
	front.audio_settings.hide()
	# Confirmed battle exit retains the preparation snapshot and earned inspiration.
	assert(run.board.place("bun", 0, 0, false).is_empty())
	run.state.elapsed = 24.0
	assert(front.saves.collect_inspiration(run.state, 3, front.data), front.saves.error)
	front.open_settings()
	front.audio_settings.menu_button.pressed.emit()
	await frames()
	assert(front.audio_settings.leave_confirmation.visible)
	await confirm_leave()
	assert(front.game == null and not front.continue_button.disabled)
	var saved: Dictionary = front.saves.load_run(front.data)
	assert(saved.units == snapshot.units and saved.heat == snapshot.heat and saved.elapsed == snapshot.elapsed)
	assert(front.saves.load_meta(front.data).inspiration == 3)
	front.continue_run()
	scene = front.game
	scene.set_process(false)
	run = scene.run
	assert(run.state.phase == "prepare" and run.state.units == snapshot.units)
	assert(run.state.collected_inspiration() == 3 and not run.paused and run.speed == 1.0)
	# Prepare and result navigation remain in settings when their write fails.
	var good_folder: String = front.saves.folder
	var blocker := FileAccess.open(good_folder.path_join("blocked"), FileAccess.WRITE)
	blocker.store_string("QA file prevents directory creation")
	blocker.close()
	blocker = null
	run.state.heat = 321
	front.open_settings()
	front.saves.folder = good_folder.path_join("blocked") + "/"
	front.audio_settings.menu_button.pressed.emit()
	await confirm_leave()
	assert(front.game == scene and front.audio_settings.visible)
	assert(not front.audio_settings.note.text.is_empty() and front.saves.error in front.audio_settings.note.text)
	front.saves.folder = good_folder
	front.audio_settings.menu_button.pressed.emit()
	await confirm_leave()
	assert(front.game == null and front.saves.load_run(front.data).heat == 321)
	front.continue_run()
	scene = front.game
	scene.set_process(false)
	run = scene.run
	scene.finish_shopping()
	run.state.phase = "lost"
	run.state.pantry = 0
	front._process(0)
	assert(front.showing_result)
	front.open_settings()
	assert(front.audio_settings.get_ok_button().text == "返回")
	front.saves.folder = good_folder.path_join("blocked") + "/"
	front.audio_settings.menu_button.pressed.emit()
	await frames()
	assert(front.showing_result and front.audio_settings.visible and front.game == scene)
	assert(not front.audio_settings.note.text.is_empty() and front.saves.error in front.audio_settings.note.text)
	front.saves.folder = good_folder
	front.audio_settings.menu_button.pressed.emit()
	await frames()
	assert(front.game == null and front.continue_button.disabled)
	var settled: Dictionary = front.saves.load_profile(front.data)
	assert(settled.meta.inspiration == 3 and settled.run.is_empty())
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	print("PASS settings: Esc/echo, shop, geometry, modal input, pause ownership, right click/shovel, 2x, leave cancel, snapshot/inspiration, prepare/result write retry")
	quit()
