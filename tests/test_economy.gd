extends SceneTree

func _init() -> void:
	var run := RunController.new()
	run.new_run(42)
	assert(not run.data.rules.has("rewards") and not run.data.rules.has("bonus"))
	assert(not run.saves.run_payload(run.state, run.rng).has("coins"))
	for stage: int in range(8):
		run.start()
		run.finish_wave()
	assert(run.shop.is_open())
	var recipe: String = run.state.choices[0]
	run.state.heat = run.data.rules.recipe_price - 0.01
	var before: float = run.state.heat
	assert(run.shop.buy_recipe(recipe) == "热量不足" and run.state.heat == before)
	run.state.heat = run.data.rules.recipe_price + 23.5
	assert(run.shop.buy_recipe(recipe).is_empty() and run.state.heat == 23.5)
	assert(not run.shop.buy_recipe(recipe).is_empty() and run.state.heat == 23.5)
	assert(run.shop.refresh() == "热量不足" and run.state.refreshes == 0)
	run.state.heat = run.data.rules.refresh_cost * 2 + 7.5
	assert(run.shop.refresh().is_empty() and run.shop.refresh().is_empty())
	assert(run.state.heat == 7.5 and not run.shop.refresh().is_empty())
	run.start()
	assert(run.state.heat == 7.5, "shopping costs cannot be refunded by starting")
	run.state.heat = 212.75
	run.finish_wave()
	assert(run.state.heat == 212.75 and run.state.refreshes == 0)
	run.start()
	assert(run.state.heat == 212.75, "heat carries through shop and battle")
	# Drive real controller collection and settlement with an isolated persistent profile.
	run.persistence = false
	run.new_run(73)
	run.saves.folder = "user://qa_economy_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	assert(run.persist())
	run.start()
	var pickup: Dictionary = drop(run)
	run.paused = true
	assert(not run.collect_inspiration(pickup.uid).is_empty())
	assert(pickup.flight == -1.0 and run.state.collected_inspiration() == 0)
	run.paused = false
	assert(run.collect_inspiration(pickup.uid).is_empty())
	assert(pickup.flight == 0.0 and run.saves.load_meta(run.data).inspiration == 1)
	assert(run.collect_inspiration(pickup.uid).is_empty())
	assert(run.state.collected_inspiration() == 1)
	assert(run.resume_run())
	assert(run.state.collected_inspiration() == 1 and run.state.heat == 150)
	run.start()
	pickup = drop(run)
	assert(run.collect_inspiration(pickup.uid).is_empty())
	assert(run.saves.load_meta(run.data).inspiration == 1, "replaying the checkpoint cannot repay old drops")
	pickup = drop(run)
	# Write failure leaves the pickup ready and does not increment the replay counter.
	var folder: String = run.saves.folder
	var blocker := FileAccess.open(folder + "blocked", FileAccess.WRITE)
	blocker.close()
	run.saves.folder = folder + "blocked/"
	assert(not run.collect_inspiration(pickup.uid).is_empty())
	assert(pickup.flight < 0 and run.combat.inspiration_collected == 1)
	run.finish_wave()
	assert(run.paused and run.state.phase == "battle" and run.state.wave == 1)
	run.saves.folder = folder
	run.paused = false
	run.finish_wave()
	assert(run.state.phase == "prepare" and run.state.wave == 2)
	assert(run.saves.load_meta(run.data).inspiration == 6, "last kill auto-collect plus existing clear reward")
	assert(run.state.collected_inspiration() == 2)
	run.start()
	pickup = drop(run)
	assert(run.collect_inspiration(pickup.uid).is_empty())
	drop(run) # Uncollected loss drop is discarded.
	run.state.pantry = 0
	run.advance(1.0 / 60.0)
	assert(run.state.phase == "lost" and run.combat.inspiration_pickups.is_empty())
	assert(run.saves.load_meta(run.data).inspiration == 7)
	assert(run.saves.settle(run.state, run.data))
	assert(run.saves.load_meta(run.data).inspiration == 7)
	# Retained drops really are usable by the existing external card shop.
	var model := MetaProgression.new(run.saves, run.data)
	assert(model.reload())
	assert(model.buy(0, int(model.profile.revision)).is_empty())
	assert(model.profile.meta.inspiration == 3 and model.profile.meta.cards.size() == 4)
	print("PASS economy: heat payments/carry, pause, duplicate pickups, immediate save, checkpoint replay, write retry, final drop, loss and external card purchase")
	quit()

func drop(run: RunController) -> Dictionary:
	var pickup: Dictionary = {"uid":run.state.uid(), "row":3, "x":300.0, "amount":1, "age":0.0, "flight":-1.0}
	run.combat.inspiration_pickups.append(pickup)
	return pickup
