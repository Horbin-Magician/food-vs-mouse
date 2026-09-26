extends SceneTree

func _init() -> void:
	call_deferred("evaluate")

func evaluate() -> void:
	var seeds: Array = [42, 7, 2026]
	var builds: Array = ["starter", "steam", "ice_fire"]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seeds = [int(argument.trim_prefix("--seed="))]
		if argument.begins_with("--build="): builds = [argument.trim_prefix("--build=")]
	for seed_value: int in seeds:
		for build: String in builds:
			evaluate_build(build, seed_value)
	quit()

func evaluate_build(build: String, seed_value: int) -> void:
	var run := RunController.new()
	run.saves.folder = "user://qa_autoplay_%d_%s_%d/" % [Time.get_ticks_usec(), build, seed_value]
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	var profile: Dictionary = run.saves.load_profile(run.data)
	var wants: Array = ["bun", "toast", "pudding"]
	if build == "steam": wants.append_array(["popcorn", "garlic"])
	elif build == "ice_fire": wants.append_array(["tea", "pepper"])
	for id: String in wants.slice(3):
		var uid: String = "card_%d" % int(profile.meta.next_card)
		profile.meta.next_card += 1
		profile.meta.cards.append({"uid":uid,"id":id,"level":0,"starter":false,"locked":false})
		profile.meta.loadout.append(uid)
	var difficulty: String = "easy"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="): difficulty = argument.trim_prefix("--difficulty=")
		if argument.begins_with("--growth="):
			for card: Dictionary in profile.meta.cards: card.level = int(argument.trim_prefix("--growth="))
	assert(run.saves.commit_profile(profile, int(profile.revision)))
	run.persistence = true
	run.new_run(seed_value, [], difficulty, "kitchen")
	assert(run.state != null, run.message)
	assert(run.state.cards.keys() == wants)
	run.persistence = false
	play(run, build, seed_value)

func play(run: RunController, build: String, seed_value: int, restore_each_wave: bool = false) -> Dictionary:
	var steps: int = 0
	var last_wave: int = 0
	var history: Array = []
	while run.state.phase not in ["won", "lost"] and steps < 60000:
		if run.state.phase == "prepare":
			if last_wave > 0: history.append(snapshot(run))
			if restore_each_wave:
				var before: Dictionary = run.saves.run_payload(run.state, run.rng)
				assert(run.resume_run())
				var after: Dictionary = run.saves.run_payload(run.state, run.rng)
				assert(JSON.parse_string(JSON.stringify(after)) == JSON.parse_string(JSON.stringify(before)))
			last_wave = run.state.global_wave()
			for id: String in run.state.choices.duplicate():
				if run.state.heat >= run.data.rules.recipe_price + 250: run.shop.buy_recipe(id)
			run.start()
		var rows: Array = []
		var threats: Array = run.combat.enemies.duplicate()
		threats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
		for enemy: Dictionary in threats:
			if not rows.has(enemy.row): rows.append(enemy.row)
		for event: Dictionary in run.director.events:
			if not rows.has(event.row): rows.append(event.row)
		var plan: Array = []
		# Early investment pays back before the first mouse crosses the kitchen.
		for row: int in [0,1,5]: plan.append(["pudding",row,0])
		for row: int in rows: plan.append(["bun",row,1])
		if run.state.global_wave() > 1:
			for row: int in [2,3,4,6]: plan.append(["pudding",row,0])
		for row: int in rows: plan.append(["toast",row,6])
		for row: int in rows:
			if build == "ice_fire":
				plan.append(["tea",row,2])
				plan.append(["pepper",row,5])
			elif build == "steam":
				plan.append(["popcorn",row,3])
				plan.append(["garlic",row,2])
			plan.append(["bun",row,4])
		for row: int in rows: plan.append(["bun",row,3 if build != "steam" else 5])
		# Reserve the next purchase budget; do not drain it on a cheaper lower priority card.
		for entry: Array in plan:
			if run.board.at(entry[1],entry[2]).is_empty():
				run.board.place(entry[0],entry[1],entry[2],false)
				break
		for pickup: Dictionary in run.combat.heat_pickups:
			if pickup.flight < 0.0: run.collect_heat(pickup.uid)
		for pickup: Dictionary in run.combat.inspiration_pickups:
			if pickup.flight < 0.0: run.collect_inspiration(pickup.uid)
		run.advance(0.25)
		steps += 1
	history.append(snapshot(run))
	var result: Dictionary = {"build":build,"seed":seed_value,"growth":run.state.levels.duplicate(),"difficulty":run.state.difficulty,"scene":run.state.scene_id,"chapter":run.state.chapter_id,"global_wave":run.state.global_wave(),"phase":run.state.phase,"wave":run.state.wave,"seconds":run.state.elapsed,"pantry":run.state.pantry,"metrics":run.state.metrics,"cards":run.state.cards,"recipes":run.state.recipes,"history":history}
	print("AUTOPLAY ", JSON.stringify(result))
	return result

func snapshot(run: RunController) -> Dictionary:
	return {"chapter":run.state.chapter_id,"wave":run.state.wave,"global_wave":run.state.global_wave(),"passed":run.state.metrics.passed,"heat":run.state.heat,"pantry":run.state.pantry,"deaths":run.state.metrics.deaths,"seconds":run.state.elapsed,"units":run.state.units.size(),"recipes":run.state.recipes.duplicate()}
