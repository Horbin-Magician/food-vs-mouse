extends SceneTree

func _init() -> void:
	call_deferred("run_test")

func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion, true)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)

func run_test() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.run.persistence = false
	scene.run.new_run(25)
	scene.run.start()
	scene.set_process(false)
	await process_frame
	await process_frame
	var source: Vector2 = scene.shovel_button.get_global_rect().get_center()
	var targets: Array[Vector2] = [source, scene.cards.get_child(0).get_global_rect().get_center(), scene.settings_button.get_global_rect().get_center(), Vector2(600, 400)]
	for target: Vector2 in targets:
		click(source)
		assert(scene.shovel and scene.shovel_cursor_active and scene.shovel_button.button_pressed)
		click(target, MOUSE_BUTTON_RIGHT)
		assert(not scene.shovel and not scene.shovel_cursor_active and not scene.shovel_button.button_pressed)
		click(source)
		var motion := InputEventMouseMotion.new()
		motion.position = target
		root.push_input(motion, true)
		var escape := InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		escape.pressed = false
		root.push_input(escape, true)
		assert(not scene.shovel and not scene.shovel_cursor_active and not scene.shovel_button.button_pressed)
		assert(scene.audio_settings.visible and scene.run.paused)
		scene.audio_settings.hide()
		scene.update_controls()
		await process_frame
		assert(not scene.run.paused)
	for repeat: int in range(20):
		click(source)
		assert(scene.shovel and scene.shovel_cursor_active)
		click(source)
		assert(not scene.shovel and not scene.shovel_cursor_active)
	assert(scene.shovel_cursor.size == Vector2(48, 48))
	click(source)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(600, 400)
	root.push_input(motion, true)
	assert(scene.shovel_cursor.visible and scene.shovel_cursor.position == Vector2(570, 392))
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN)
	root.mouse_exited.emit()
	assert(not scene.shovel_cursor.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	root.mouse_entered.emit()
	root.focus_exited.emit()
	assert(not scene.shovel_cursor.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	root.focus_entered.emit()
	root.push_input(motion, true)
	assert(scene.shovel_cursor.visible)
	if "--capture-shovel" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/fvm_shovel_visible.png")
		root.size = Vector2i(1600, 900)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/fvm_shovel_large.png")
	scene.hide()
	assert(not scene.shovel_cursor.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	scene.show()
	assert(scene.shovel_cursor.visible)
	scene.shovel = false
	assert(not scene.run.paused and scene.selected.is_empty())
	assert(scene.run.state.units.is_empty() and scene.run.state.heat == 150)
	# Releasing the scene while holding the shovel must restore the OS cursor.
	scene.shovel = true
	assert(scene.shovel_cursor_active)
	scene.queue_free()
	await process_frame
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("PASS shovel: repeated pickup, return, cancel, focus and active scene cleanup, no gameplay mutation")
	await create_timer(0.5).timeout
	quit()
