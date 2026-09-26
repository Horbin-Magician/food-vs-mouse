extends SceneTree

const OUTPUT_PREFIX: String = "/tmp/food_ui_refresh_"
const DIMENSIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900)]
const LOADOUT: Array[String] = ["card_1", "card_2", "card_3", "card_7", "card_8"]
var front: Node
var capture_count: int = 0

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = DIMENSIONS[0]
	front = load("res://scenes/front_end.tscn").instantiate()
	# Set storage before _ready, then restore it if a generic QA flag changes it.
	var folder: String = "user://qa_ui_refresh_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	front.saves.folder = folder
	root.add_child(front)
	front.saves.folder = folder
	front.sound.settings_path = folder.path_join("audio.cfg")
	front.sound.load_settings()
	front.audio_settings.setup(front.sound)
	front.set_process(false)
	front.show_menu()
	assert(front.continue_button.disabled)
	if not await snap_both("menu_new"): return

	seed_collection()
	front.show_hub("shop")
	if not await snap_both("card_shop"): return
	set_inspiration(0)
	front.hub.rebuild()
	if not await snap_both("card_shop_insufficient"): return
	set_inspiration(140)
	front.hub.tab = "enhance"
	front.hub.main_uid = ""
	front.hub.materials.clear()
	front.hub.rebuild()
	if not await snap_both("enhance_empty"): return
	front.hub.main_uid = "card_1"
	front.hub.materials = ["card_4"]
	var risk: Dictionary = front.hub.model.preview(front.hub.main_uid, front.hub.materials)
	assert(risk.error.is_empty() and risk.chance > 0.0 and risk.chance < 1.0)
	front.hub.rebuild()
	if not await snap_both("enhance_risk"): return
	front.hub.materials = ["card_5", "card_6"]
	var guaranteed: Dictionary = front.hub.model.preview(front.hub.main_uid, front.hub.materials)
	assert(guaranteed.error.is_empty() and is_equal_approx(guaranteed.chance, 1.0))
	front.hub.rebuild()
	if not await snap_both("enhance_guaranteed"): return
	front.hub.tab = "loadout"
	front.hub.selected.clear()
	front.hub.rebuild()
	if not await snap_both("loadout_empty"): return
	front.hub.selected = ["card_2", "card_3"]
	front.hub.rebuild()
	if not await snap_both("loadout_no_attack"): return
	front.hub.selected = LOADOUT.duplicate()
	front.hub.rebuild()
	if not await snap_both("loadout_five"): return

	front.start_new(LOADOUT.duplicate())
	assert(is_instance_valid(front.game))
	front.game.set_process(false)
	var run: RunController = front.game.run
	run.state.choices = ["pressure", "caramel", "reheat"]
	run.state.heat = run.data.rules.recipe_price - 1
	front.game.rebuild()
	if not await snap_both("recipes_insufficient"): return
	run.state.heat = run.data.rules.recipe_price * 2 + run.data.rules.heat_start
	front.game.rebuild()
	if not await snap_both("recipes_available"): return
	run.state.refreshes = run.data.rules.refresh_limit
	front.game.rebuild()
	if not await snap_both("recipes_refresh_exhausted"): return
	run.state.refreshes = 0
	run.state.recipes = run.data.recipes.keys()
	run.state.choices.clear()
	front.game.rebuild()
	if not await snap_both("recipes_empty"): return
	# Restore a normal preparation snapshot before the continuation/battle cases.
	run.state.recipes.clear()
	run.state.choices = ["pressure", "caramel", "reheat"]
	front.game.rebuild()
	assert(run.persist(), run.message)
	front.show_menu()
	assert(not front.continue_button.disabled)
	if not await snap_both("menu_continue"): return
	front.continue_run()
	assert(is_instance_valid(front.game))
	front.game.set_process(false)
	front.game.finish_shopping()
	run = front.game.run
	assert(run.state.phase == "battle")
	run.persistence = false
	populate_battle(run)
	if not await snap_both("battle_cooldowns"): return
	front.game.settings_button.pressed.emit()
	assert(front.audio_settings.visible and run.paused)
	if not await snap_both("settings"): return
	front.audio_settings.menu_button.pressed.emit()
	assert(front.audio_settings.leave_confirmation.visible)
	if not await snap_both("leave_confirmation"): return
	front.audio_settings.handle_escape()
	front.audio_settings.hide()
	assert(not run.paused)

	# Result fixtures retain the real run ID; only this isolated profile is settled.
	run.state.chapter_id = "kitchen_5"
	run.state.wave = 8
	run.state.phase = "won"
	run.state.elapsed = 847
	run.state.metrics.passed = 40
	run.state.metrics.kills = 204
	run.state.metrics.leaks = 2
	run.state.metrics.deaths = 9
	run.state.pantry = 8
	run.message = "今夜粮仓守住了！"
	front._process(0)
	assert(front.showing_result)
	if not await snap_both("result_won"): return
	front.leave_result("new")
	assert(front.game == null and is_instance_valid(front.hub))
	front.start_new(LOADOUT.duplicate())
	assert(is_instance_valid(front.game))
	front.game.set_process(false)
	front.game.finish_shopping()
	run = front.game.run
	run.persistence = false
	run.state.wave = 4
	run.state.phase = "lost"
	run.state.elapsed = 392
	run.state.metrics.passed = 3
	run.state.metrics.kills = 61
	run.state.metrics.leaks = 10
	run.state.metrics.deaths = 5
	run.state.pantry = 0
	run.message = "粮仓失守。调整阵型，再试一次。"
	front._process(0)
	assert(front.showing_result)
	if not await snap_both("result_lost"): return
	front.leave_result("menu")
	root.size = DIMENSIONS[0]
	front.set_process(true)
	print("PASS UI refresh gallery: %d captures at %s*.png; isolated storage %s" % [capture_count, OUTPUT_PREFIX, folder])
	if "--manual" in OS.get_cmdline_user_args():
		print("UI refresh manual fixture ready: isolated main menu, rich collection, five-card loadout; no player saves used")
		return
	await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
	quit()

func seed_collection() -> void:
	var profile: Dictionary = front.saves.load_profile(front.data)
	assert(not profile.is_empty() and profile.run.is_empty())
	profile.meta.inspiration = 140
	profile.meta.cards[0].level = 6
	for index: int in range(17):
		var uid: String = "card_%d" % int(profile.meta.next_card)
		profile.meta.next_card += 1
		profile.meta.cards.append({"uid": uid, "id": ArtCatalog.FOOD_IDS[index % 8], "level": index % 7, "starter": false, "locked": index == 12})
	# Keep card_4 at +0 for the risky preview; two +6 cards guarantee +6 -> +7.
	MetaProgression.card(profile.meta, "card_5").level = 6
	MetaProgression.card(profile.meta, "card_6").level = 6
	profile.meta.offers = []
	var offers: Array[String] = ["tea", "pepper", "popcorn", "garlic"]
	for index: int in range(front.data.progression.shop_slots):
		profile.meta.offers.append({"id": offers[index % offers.size()], "bought": false})
	assert(front.saves.commit_profile(profile, int(profile.revision)), front.saves.error)

func set_inspiration(amount: int) -> void:
	var profile: Dictionary = front.saves.load_profile(front.data)
	profile.meta.inspiration = amount
	assert(front.saves.commit_profile(profile, int(profile.revision)), front.saves.error)
	assert(front.hub.model.reload(), front.hub.model.error)

func populate_battle(run: RunController) -> void:
	for row: int in range(7):
		put(run, "bun", row, 1)
		put(run, "toast", row, 5)
		put(run, "tea" if row % 2 == 0 else "pepper", row, 3)
		var unit: Dictionary = run.board.at(row, 5)
		unit.hp *= 0.55 + row * 0.05
	put(run, "pudding", 0, 0)
	put(run, "pudding", 3, 0)
	put(run, "pudding", 6, 0)
	var enemies: Array[String] = ["gray", "lid", "runner", "gnawer", "flour", "drummer", "gray"]
	for row: int in range(7):
		for index: int in range(2):
			run.combat.spawn(enemies[row], row, run.data.waves[0])
			run.combat.enemies[-1].x = 645 + index * 95 + row * 8
	run.state.heat = 83
	run.state.cooldowns = {"bun": 3.5, "toast": 7.0, "tea": 4.0}
	run.state.elapsed = 42.0
	run.state.pantry = 7
	front.game.rebuild()
	front.game.animator.bind(run, front.game.projection)
	front.game.animator.advance(1.0, run.combat.enemies)

func put(run: RunController, id: String, row: int, col: int) -> void:
	run.state.heat = run.data.rules.heat_cap
	run.state.cooldowns.clear()
	assert(run.board.place(id, row, col, false).is_empty())

func snap_both(label: String) -> bool:
	for dimensions: Vector2i in DIMENSIONS:
		root.size = dimensions
		if is_instance_valid(front.game) and not front.showing_result:
			front.game._process(0)
		await process_frame
		await process_frame
		# Force a render even when another native window covers this fixture.
		RenderingServer.force_draw(false)
		var path: String = "%s%d_%s.png" % [OUTPUT_PREFIX, dimensions.x, label]
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("Could not save UI refresh capture: " + path)
			await preload("res://tests/audio_cleanup.gd").release_scene(front, self)
			quit(1)
			return false
		capture_count += 1
	return true
