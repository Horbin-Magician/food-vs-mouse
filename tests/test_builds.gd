extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(42)
	var same: RunController = RunController.new()
	same.new_run(42)
	for controller: RunController in [run, same]:
		for stage: int in range(8):
			controller.start()
			controller.finish_wave()
		assert(controller.shop.is_open())
	assert(run.state.offers == same.state.offers and run.state.choices == same.state.choices)
	run.state.levels.bun = 10
	run.start()
	run.board.place("bun",2,0,false)
	run.state.units[0].hp = 100.0
	run.state.phase = "prepare"
	var heat: float = run.state.heat
	assert(run.shop.buy(0) != "" and run.state.heat == heat)
	assert(run.state.units[0].hp == 100.0 and run.state.star("bun") == 1)
	for id: String in run.data.foods: run.state.cards[id] = 1
	run.shop.generate()
	assert(run.state.offers.is_empty())
	run.state.recipes = ["pressure","wide","breakfast","cold_spice","burn","ice"]
	run.state.units[0].attacks = 4
	assert(is_equal_approx(run.recipes.radius(run.state.units[0]),0.75))
	run.state.phase = "battle"
	run.state.heat = 350
	run.board.place("pudding",2,1,false)
	assert(is_equal_approx(run.recipes.damage(run.state.units[0]),12*1.5*1.15))
	run.combat.spawn("lid",2,run.data.waves[0])
	var enemy: Dictionary = run.combat.enemies[0]
	run.combat.damage_enemy(enemy,run.recipes.value("burn", "damage"),"pepper",false)
	assert(enemy.armor == 3 and enemy.hp == 257.0)
	enemy.slow_time = 2
	run.combat.damage_enemy(enemy,32,"pepper")
	assert(enemy.hp == 221.0 and enemy.armor == 2)
	run.state.phase = "prepare"
	run.state.recipes.clear()
	run.recipes.offer(run.rng,[])
	var choice: String = run.state.choices[0]
	run.state.heat = 0
	assert(run.shop.buy_recipe(choice) != "" and run.state.recipes.is_empty())
	run.state.heat = run.data.rules.recipe_price + 150
	run.state.phase = "battle"
	assert(run.shop.buy_recipe(choice) != "" and run.state.heat == run.data.rules.recipe_price + 150)
	run.state.phase = "prepare"
	assert(run.shop.buy_recipe(choice) == "")
	assert(run.state.heat == 150 and run.recipes.has(choice))
	assert(run.shop.buy_recipe(choice) != "")
	assert(run.state.heat == 150)
	run.state.recipes = run.data.recipes.keys()
	run.recipes.offer(run.rng,[])
	assert(run.state.choices.is_empty())
	assert(run.state.phase == "prepare")
	print("PASS builds: deterministic shop, atomic recipe purchases, permanent levels, stacked formulas, armor, empty recipes")
	quit()
