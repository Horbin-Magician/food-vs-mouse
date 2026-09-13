extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(1)
	run.start()
	for row: int in range(5):
		run.state.heat = 350
		run.state.cooldowns.clear()
		assert(run.board.place("pudding",row,0,false) == "")
	run.state.heat = 350
	run.state.cooldowns.clear()
	assert(run.board.place("pudding",0,1,false) == "" and run.state.heat == 300)
	for row: int in range(RunState.ROWS):
		for col: int in range(RunState.COLS):
			if not run.board.at(row,col).is_empty(): continue
			run.state.heat = 350
			run.state.cooldowns.clear()
			assert(run.board.place("toast",row,col,false) == "")
	assert(run.state.units.size() == 63)
	assert(run.board.place("bun",7,0,false) != "")
	assert(run.board.place("bun",0,9,false) != "")
	var heat: float = run.state.heat
	assert(run.board.place("bun",0,0,false) != "" and run.state.heat == heat)
	run.state.phase = "prepare"
	var first: Dictionary = run.board.at(0,0)
	var second: Dictionary = run.board.at(1,1)
	first.hp = 31.0
	second.hp = 80.0
	assert(run.board.move(0,0,1,1) == "")
	assert(run.board.at(1,1).uid == first.uid and run.board.at(1,1).hp == 31.0)
	assert(run.board.at(0,0).uid == second.uid and run.board.at(0,0).hp == 80.0)
	assert(run.state.units.size() == 63)
	run.saves.folder = "user://qa_grid/"
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	assert(run.saves.save_run(run.state,run.rng))
	var loaded: Dictionary = run.saves.load_run(run.data)
	assert(not loaded.is_empty() and loaded.units.size() == 63)
	assert(run.saves.restore(loaded).units == run.state.units)
	run.start()
	run.state.heat = 0
	for unit: Dictionary in run.state.units: unit.timer = 0.0
	for i: int in range(599): run.combat.step(1.0/60.0)
	assert(run.state.heat < 20.0 and run.combat.heat_pickups.is_empty(),"production waits full cycle")
	for i: int in range(2): run.combat.step(1.0/60.0)
	assert(run.state.heat < 21.0 and run.combat.heat_pickups.size() == 6,"production creates pickups without direct credit")
	run.new_run(2)
	run.start()
	for i: int in range(4):
		run.combat.spawn("gray",2,run.data.waves[0])
		run.combat.enemies.back().x = 100.0+i*2
	run.combat.projectiles.append({"row":2,"x":90.0,"damage":22.0,"source":"noodles","radius":0.0,"remaining":3,"hit":[]})
	run.combat.step(1.0/60.0)
	for i: int in range(3): assert(run.combat.enemies[i].hp == 78.0)
	assert(run.combat.enemies[3].hp == 100 and run.combat.projectiles.is_empty())
	run.combat.spawn("gray",1,run.data.waves[0])
	run.combat.enemies.back().x = 100.0
	run.combat.hit({"source":"popcorn","damage":200.0,"radius":70.0},run.combat.enemies[0])
	assert(run.combat.enemies.size() == 1 and run.combat.enemies[0].row == 1,"simultaneous area deaths restricted to lane")
	run.combat.clear()
	run.combat.spawn("lid",2,run.data.waves[0])
	var enemy: Dictionary = run.combat.enemies[0]
	run.state.recipes = ["burn","ice"]
	enemy.burn_time = 3.0
	for i: int in range(181): run.combat.step(1.0/60.0)
	assert(is_equal_approx(enemy.hp,242.0) and enemy.armor == 3,"burn three ticks ignores armor")
	run.combat.hit({"source":"tea","damage":12.0,"radius":0.0},enemy)
	assert(enemy.slow == 0.4)
	var timer: float = enemy.slow_time
	run.paused = true
	run.advance(0.25)
	assert(enemy.slow_time == timer)
	run.paused = false
	run.speed = 2
	var time_before: float = run.director.elapsed
	run.advance(0.25)
	assert(absf(run.director.elapsed-time_before-0.5)<0.017 and absf(timer-enemy.slow_time-0.5)<0.017)
	for seed_value: int in range(100):
		var a: RandomNumberGenerator = RandomNumberGenerator.new()
		var b: RandomNumberGenerator = RandomNumberGenerator.new()
		a.seed = seed_value
		b.seed = seed_value
		var d1: WaveDirector = WaveDirector.new()
		var d2: WaveDirector = WaveDirector.new()
		d1.begin(run.data.waves[7],a)
		d2.begin(run.data.waves[7],b)
		assert(d1.events == d2.events)
		for i: int in range(2,d1.events.size()):
			assert(not (d1.events[i].row == d1.events[i-1].row and d1.events[i].row == d1.events[i-2].row))
	print("PASS edges: full board, unlimited pudding, swap identity, production, piercing, area deaths, burn, slow, speed, 100 seeds")
	quit()
