extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(25)
	run.start()
	run.board.place("bun",2,0,false)
	run.state.units[0].hp = 90.0
	run.finish_wave()
	run.combat.clear()
	run.state.choices = ["pressure","reheat","caramel"]
	run.saves.folder = "user://qa_visual/"
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	assert(run.saves.save_run(run.state,run.rng))
	print("Prepared isolated visual fixture: wave 2 shop, damaged bun")
	quit()
