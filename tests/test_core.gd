extends SceneTree

var checks: int = 0
func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		push_error(title)
		quit(1)
		assert(value, title)

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(42)
	run.start()
	check(run.board.place("bun",2,0,false) == "", "legal placement")
	var heat: float = run.state.heat
	check(run.board.place("bun",2,0,false) != "" and run.state.heat == heat,"duplicate atomic")
	check(run.board.place("bun",2,1,false) != "" and run.state.units.size() == 1,"cooldown atomic")
	check(run.board.place("toast",1,0,false) != "", "insufficient heat")
	check(run.board.place("pudding",1,0,true) != "", "pause placement")
	run.paused = true
	run.advance(1.0)
	check(run.state.heat == heat and run.director.elapsed == 0, "pause all clocks")
	run.paused = false
	run.combat.spawn("gray",2,run.data.waves[0])
	run.combat.enemies[0].x = 200.0
	for i: int in range(600): run.advance(1.0/60.0)
	check(run.state.metrics.kills >= 1, "projectile kills")
	run.state.pantry = 1
	run.combat.clear()
	run.combat.spawn("gray",0,run.data.waves[0])
	run.combat.enemies[0].x = -1.0
	run.director.cursor = run.director.events.size()
	run.advance(1.0/60.0)
	check(run.state.phase == "lost", "pantry zero takes priority over clear")
	print("PASS core ", checks)
	quit(0)
