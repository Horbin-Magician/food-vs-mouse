extends SceneTree

const OUTPUT_PREFIX: String = "/tmp/kitchen_continuous_"
var front: Node
var capture_count: int = 0

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	front = load("res://scenes/front_end.tscn").instantiate()
	var folder: String = "user://qa_continuous_gallery_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	front.saves.folder = folder
	root.add_child(front)
	front.saves.folder = folder
	front.set_process(false)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1600,900)]:
		root.size = dimensions
		front.show_menu()
		front.prepare_new()
		var selector: OptionButton = front.hub.find_child("SceneSelect",true,false)
		assert(selector.item_count == 1 and selector.get_item_metadata(0) == "kitchen")
		assert(not selector.is_item_disabled(0) and front.hub.find_child("ChapterSelect",true,false) == null)
		for chapter_id: String in front.data.scene_chapters("kitchen"):
			var route: Control = front.hub.find_child("ChapterRoute_" + chapter_id,true,false)
			assert(route != null and not route is BaseButton)
		await snap("scene_%d" % dimensions.x)
		var launch: Button = front.hub.find_child("Launch",true,false)
		launch.pressed.emit()
		assert(front.game.run.state.scene_id == "kitchen" and front.game.run.state.chapter_id == "kitchen_1")
		front.game.set_process(false)
		await snap("shop_1_1_%d" % dimensions.x)
		# UI route fixture: normal transitions and saves; combat itself is sampled separately.
		var run: RunController = front.game.run
		run.state.heat = 1400
		run.state.pantry = 7
		assert(run.shop.buy_recipe(run.state.choices[0]).is_empty())
		var expected_recipes: Array = run.state.recipes.duplicate()
		var expected_heat: float = run.state.heat - 175
		for index: int in range(40):
			front.game.finish_shopping()
			if index == 0:
				assert(run.board.place("bun",2,1,false).is_empty())
				assert(run.board.place("toast",2,5,false).is_empty())
				run.state.units[0].hp *= 0.6
			assert(run.state.phase == "battle")
			if index in [8,39]:
				run.paused = true
				await snap("battle_%d_%d_%d" % [front.data.chapters[run.state.chapter_id].order,run.state.wave,dimensions.x])
				run.paused = false
			run.finish_wave()
			front.game.rebuild()
			front._process(0)
			if index < 39:
				assert(not front.showing_result and run.state.phase == "prepare")
			if index in [7,15,23,31]:
				assert(run.state.wave == 1 and run.state.global_wave() == index + 2)
				assert(run.state.units.size() == 2 and run.state.pantry == 7 and run.state.recipes == expected_recipes)
				assert(run.state.heat == expected_heat)
				assert(front.game.earned_inspiration() == front.run_inspiration(run.state))
				assert(front.game.shop_surface.get_node("SceneProgress").text.contains("总 %02d/40" % (index + 2)))
				await snap("shop_%d_1_%d" % [front.data.chapters[run.state.chapter_id].order,dimensions.x])
				front.show_menu()
				assert(front.continue_button.text.contains("总 %02d/40" % (index + 2)))
				if index == 7: await snap("continue_2_1_%d" % dimensions.x)
				front.continue_run()
				front.game.set_process(false)
				run = front.game.run
				assert(run.state.global_wave() == index + 2 and run.state.units.size() == 2)
		assert(front.showing_result and run.state.phase == "won" and run.state.metrics.passed == 40)
		assert(front.run_inspiration(run.state) > 0 and "下一夜" not in front.notice.text)
		assert("首通共 +60" in front.notice.text if dimensions.x == 1280 else "首通" not in front.notice.text)
		await snap("won_%d" % dimensions.x)
		front.leave_result("menu")
		assert(front.continue_button.disabled)
	print("PASS continuous campaign UI: scene-only selection, four retained boundaries and resumes, 40-wave final/repeat result; %d native captures" % capture_count)
	if "--manual" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		front.prepare_new()
		front.set_process(true)
		print("Continuous campaign manual fixture ready; isolated profile: " + folder)
		return
	await preload("res://tests/audio_cleanup.gd").release_scene(front,self)
	quit()

func snap(label: String) -> void:
	if is_instance_valid(front.game) and not front.showing_result: front.game._process(0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(OUTPUT_PREFIX + label + ".png") == OK)
	capture_count += 1
