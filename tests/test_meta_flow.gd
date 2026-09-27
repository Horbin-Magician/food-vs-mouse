extends SceneTree

func _init() -> void:
	var saves := SaveService.new()
	saves.folder = "user://qa_meta_flow_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(saves.folder)
	var data := Catalog.new()
	var model := MetaProgression.new(saves,data)
	assert(model.reload())
	var p: Dictionary = saves.load_profile(data)
	MetaProgression.card(p.meta,"card_1").level = 6
	MetaProgression.card(p.meta,"card_3").level = 5
	assert(saves.commit_profile(p,int(p.revision)))
	var run := RunController.new()
	run.saves = saves
	run.persistence = true
	run.new_run(713,["card_1","card_3"])
	assert(run.state.cards.size() == 2 and run.state.level("bun") == 6)
	assert(run.state.offers.is_empty())
	assert(is_equal_approx(run.board.max_hp("bun"),234.0))
	assert(is_equal_approx(run.state.production_multiplier("pudding",data),1.1))
	assert(run.shop.buy(0) != "")
	assert("crust" not in run.state.choices)
	model.reload()
	assert(not model.refresh(int(model.profile.revision)).is_empty())
	var rng: int = run.rng.state
	assert(run.persist() and run.rng.state == rng)
	run.start()
	assert(run.board.place("bun",2,0,false).is_empty())
	assert(is_equal_approx(run.recipes.damage(run.state.units[0]),run.data.foods["bun"].stats.damage * 1.3))
	run.finish_wave()
	assert(saves.load_meta(data).inspiration == 4)
	assert(run.state.wave == 2 and run.state.phase == "prepare")
	var balance: int = int(saves.load_meta(data).inspiration)
	run.finish_wave()
	run.persist()
	assert(saves.load_meta(data).inspiration == balance)
	assert(run.resume_run() and run.state.level("bun") == 6 and run.state.cards.size() == 2)
	run.start()
	run.finish_wave()
	assert(saves.load_meta(data).inspiration == 9)
	run.start()
	run.state.pantry = 0
	run.advance(0.02)
	assert(run.state.phase == "lost" and saves.load_meta(data).inspiration == 9)
	var settled: Dictionary = saves.load_profile(data)
	assert(settled.run.is_empty() and settled.meta.refreshes == 0)
	assert(saves.settle(run.state,data) and saves.load_profile(data) == settled)
	run.new_run(14)
	assert(run.state.cards.size() == 2)
	run.start()
	run.finish_wave()
	assert(saves.load_meta(data).inspiration == 13)
	assert(saves.settle(run.state,data)) # abandon retains earned inspiration
	assert(saves.load_meta(data).inspiration == 13)
	# Legacy migration preserves its stars and never retroactively pays cleared waves.
	var old := SaveService.new()
	old.folder = "user://qa_meta_legacy_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(old.folder)
	assert(old.write_json("meta.json",{"kills":100,"unlocked":["wide"],"last_run":"old"}))
	run.persistence = false
	run.new_run(77)
	run.state.cards = {"bun":6,"toast":1,"pudding":1}
	run.state.wave = 4
	run.state.metrics.passed = 3
	var payload: Dictionary = saves.run_payload(run.state,run.rng)
	for field: String in ["loadout","levels","legacy_stars","reward_floor","rewards_enabled"]: payload.erase(field)
	payload.offers = [{"id":"bun","bought":false},{"id":"bun","bought":false},{"id":"tea","bought":false}]
	assert(old.write_json("run.json",payload))
	run.saves = old
	run.persistence = true
	assert(run.resume_run() and run.state.legacy_stars and run.state.star("bun") == 3)
	assert(run.persist() and old.load_meta(data).inspiration == 0)
	run.start()
	run.finish_wave()
	assert(old.load_meta(data).inspiration == 8)
	assert(old.load_meta(data).kills == 100 and "wide" in old.load_meta(data).unlocked)
	assert(FileAccess.file_exists(old.folder.path_join("run.json")))
	# Old settle could finish writing meta before removing its run; import its receipt.
	var interrupted := SaveService.new()
	interrupted.folder = "user://qa_meta_interrupted_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(interrupted.folder)
	assert(interrupted.write_json("meta.json",{"kills":100,"unlocked":["wide"],"last_run":payload.run_id}))
	assert(interrupted.write_json("run.json",payload))
	assert(interrupted.load_run(data).is_empty() and "已结算" in interrupted.error)
	assert(interrupted.load_meta(data).kills == 100 and interrupted.load_meta(data).inspiration == 0)
	# Reject unknown player versions without falling back to the obsolete legacy files.
	var file := FileAccess.open(old.folder.path_join("player.json"),FileAccess.WRITE)
	file.store_string('{"version":999,"payload":{}}')
	file.close()
	assert(old.load_profile(data).is_empty() and not old.error.is_empty())
	assert(not run.persist())
	print("PASS meta flow: selected stats, recipe-only shop, per-wave inspiration, loss/abandon, checkpoint/reward idempotency, legacy and unknown-version handling")
	quit()
