extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_meta_gallery_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	front.show_menu()
	await snap("menu")
	front.show_hub("shop")
	var model: MetaProgression = front.hub.model
	var p: Dictionary = front.saves.load_profile(front.data)
	p.meta.inspiration = 140
	p.meta.cards[0].level = 6
	for i: int in range(17):
		var uid: String = "card_%d" % int(p.meta.next_card)
		p.meta.next_card += 1
		p.meta.cards.append({"uid":uid,"id":ArtCatalog.FOOD_IDS[i % 8],"level":i % 7,"starter":false,"locked":false})
	assert(front.saves.commit_profile(p,int(p.revision)))
	model.reload()
	front.hub.rebuild()
	await snap("shop")
	front.hub.tab = "enhance"
	front.hub.main_uid = "card_1"
	front.hub.materials = ["card_4","card_5","card_6"]
	front.hub.rebuild()
	await snap("enhance")
	root.size = Vector2i(1600,900)
	await snap("enhance_large")
	front.hub.tab = "loadout"
	front.hub.selected = ["card_1","card_2","card_3","card_7","card_8"]
	front.hub.rebuild()
	await snap("loadout_large")
	root.size = Vector2i(1280,720)
	front.start_new(front.hub.selected)
	await snap("recipes")
	front.game.finish_shopping()
	await snap("battle")
	front.game.run.finish_wave()
	front.game.run.start()
	front.game.run.state.pantry = 0
	front.game.run.advance(0.02)
	front._process(0)
	await snap("result")
	front.leave_result("menu")
	front.show_hub("shop")
	if "--hold" in OS.get_cmdline_user_args(): return
	front.queue_free()
	await process_frame
	quit()

func snap(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/food_meta_"+label+".png")
