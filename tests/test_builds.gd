extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(42)
	var same: RunController = RunController.new()
	same.new_run(42)
	assert(run.state.offers == same.state.offers)
	run.state.cards.bun = 2
	run.start()
	run.board.place("bun",2,0,false)
	run.state.units[0].hp = 100.0
	run.state.phase = "prepare"
	run.state.offers = [{"id":"bun","bought":false}]
	assert(run.shop.buy(0) == "")
	assert(run.state.star("bun") == 2 and is_equal_approx(run.state.units[0].hp,163.0))
	var coins: int = run.state.coins
	assert(run.shop.buy(0) != "" and run.state.coins == coins)
	run.state.coins = 0
	run.state.offers = [{"id":"tea","bought":false}]
	assert(run.shop.buy(0) != "" and not run.state.cards.has("tea"))
	for id: String in run.data.foods: run.state.cards[id] = 6
	run.shop.generate()
	assert(run.state.offers[0].id == "")
	run.state.recipes = ["pressure","wide","breakfast","cold_spice","burn","ice"]
	run.state.units[0].attacks = 4
	assert(is_equal_approx(run.recipes.radius(run.state.units[0]),0.75))
	run.state.phase = "battle"
	run.state.heat = 350
	run.board.place("pudding",2,1,false)
	assert(is_equal_approx(run.recipes.damage(run.state.units[0]),24*1.75*1.15))
	run.combat.spawn("lid",2,run.data.waves[0])
	var enemy: Dictionary = run.combat.enemies[0]
	run.combat.damage_enemy(enemy,6,"pepper",false)
	assert(enemy.armor == 3 and enemy.hp == 254)
	enemy.slow_time = 2
	run.combat.damage_enemy(enemy,32,"pepper")
	assert(enemy.hp == 218 and enemy.armor == 2)
	run.state.phase = "recipe"
	run.state.recipes.clear()
	run.recipes.offer(run.rng,[])
	var choice: String = run.state.choices[0]
	assert(run.recipes.choose(choice) == "")
	assert(run.recipes.choose(choice) != "")
	for id: String in run.data.recipes: run.state.recipes.append(id)
	run.recipes.offer(run.rng,[])
	assert(run.state.choices.is_empty())
	run.skip_recipe()
	assert(run.state.phase == "prepare")
	print("PASS builds: deterministic shop, atomic purchases, stars, stacked formulas, armor, empty recipes")
	quit()
