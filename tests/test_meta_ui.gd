extends SceneTree

func _init() -> void:
	call_deferred("check")

func check() -> void:
	var front = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = "user://qa_meta_ui_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(front.saves.folder)
	front.show_menu()
	front.request_new()
	assert(front.game == null and front.hub.tab == "loadout")
	var hub: CardHub = front.hub
	var p: Dictionary = front.saves.load_profile(front.data)
	p.meta.inspiration = 40
	assert(front.saves.commit_profile(p,int(p.revision)))
	hub.model.reload()
	hub.tab = "shop"
	hub.rebuild()
	await process_frame
	var buy: Button = hub.find_child("Buy_0",true,false)
	assert(not buy.disabled)
	buy.pressed.emit()
	assert(hub.model.profile.meta.cards.size() == 4)
	assert(hub.model.profile.meta.inspiration == 36)
	# A queued duplicate callback carries the stale revision and cannot purchase again.
	buy.pressed.emit()
	assert(hub.model.profile.meta.inspiration == 36)
	var buy_other: Button = hub.find_child("Buy_1",true,false)
	buy_other.pressed.emit()
	hub.tab = "enhance"
	hub.main_uid = "card_1"
	hub.materials = ["card_4","card_5"]
	hub.rebuild()
	await process_frame
	var enhance: Button = hub.find_child("Enhance",true,false)
	assert(not enhance.disabled)
	enhance.pressed.emit()
	assert(MetaProgression.card(hub.model.profile.meta,"card_1").level == 1)
	assert(hub.materials.is_empty() and hub.model.profile.meta.cards.size() == 3)
	assert("强化成功" in hub.feedback)
	hub.tab = "loadout"
	hub.choose("card_2")
	assert(hub.selected == ["card_1","card_3"])
	hub.rebuild()
	await process_frame
	var launch: Button = hub.find_child("Launch",true,false)
	assert(not launch.disabled)
	launch.pressed.emit()
	assert(front.game != null and front.game.run.state.cards.size() == 2)
	assert(front.game.run.state.level("bun") == 1 and front.game.shop_overlay.visible)
	front.game.finish_shopping()
	assert(front.game.run.state.phase == "battle")
	front.game.run.finish_wave()
	assert(front.saves.load_meta(front.data).inspiration == 36)
	front.game.run.start()
	front.game.run.state.pantry = 0
	front.game.run.advance(0.02)
	front._process(0)
	assert(front.showing_result and front.run_inspiration(front.game.run.state) == 4)
	front.leave_result("menu")
	front.show_hub("shop")
	assert(front.hub.model.profile.meta.refreshes == 0 and front.hub.model.profile.meta.inspiration == 36)
	front.queue_free()
	await process_frame
	await create_timer(0.5).timeout
	print("PASS meta UI: new-game selection, buy, duplicate callback, enhance, selected launch, recipe shop, loss and inspiration")
	quit()
