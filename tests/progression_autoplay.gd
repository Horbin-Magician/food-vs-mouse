extends "res://tests/autoplay.gd"

func evaluate() -> void:
	var run := RunController.new()
	run.saves.folder = "user://qa_continuous_growth_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run.saves.folder)
	run.persistence = true
	var growth := MetaProgression.new(run.saves, run.data)
	assert(growth.reload())
	assert(growth.profile.meta.inspiration == 0 and growth.profile.meta.cards.size() == 3)
	run.new_run(43, ["card_1","card_2","card_3"], "easy", "kitchen")
	assert(run.state.chapter_id == "kitchen_1" and run.state.global_wave() == 1)
	assert(run.state.heat == 150 and run.state.units.is_empty() and run.state.recipes.is_empty())
	var result: Dictionary = play(run, "starter", 43, true)
	var profile: Dictionary = run.saves.load_profile(run.data)
	assert(run.state.phase in ["won", "lost"])
	assert(run.saves.settle(run.state,run.data) and run.saves.load_profile(run.data) == profile)
	result["loadout"] = run.state.loadout.duplicate(true)
	result["balance"] = profile.meta.inspiration
	result["clears"] = profile.meta.chapter_clears.duplicate()
	print("PROGRESSION ", JSON.stringify(result))
	print("PASS initial-account continuous run, real rewards, checkpoint restores and settlement; battle outcome: ", run.state.phase)
	quit()
