extends SceneTree

func _init() -> void:
	var run: RunController = RunController.new()
	run.new_run(99)
	assert(run.data.foods.size() == 8 and run.data.recipes.size() == 12 and run.data.waves.size() == 8)
	for wave: Resource in run.data.waves:
		var director: WaveDirector = WaveDirector.new()
		director.begin(wave,run.rng)
		assert(director.events[0].row != director.events[1].row and director.events[1].row != director.events[2].row and director.events[0].row != director.events[2].row)
		for i: int in range(2,director.events.size()):
			assert(not (director.events[i].row == director.events[i-1].row and director.events[i].row == director.events[i-2].row))
			assert(run.data.enemies.has(director.events[i].id))
	assert(run.data.waves[0].stats.rows == [2,3,4])
	assert(run.data.waves[7].stats.rows == [0,1,2,3,4,5,6])
	var final_director: WaveDirector = WaveDirector.new()
	final_director.begin(run.data.waves[7],run.rng)
	assert(final_director.events.back().row == 3)
	run.state.wave = 8
	run.start()
	run.combat.spawn("boss",2,legacy_boss_wave(run))
	var boss: Dictionary = run.combat.enemies[0]
	assert(boss.hp == 2600 and boss.dps == 60)
	run.combat.damage_enemy(boss,1400,"bun")
	assert(boss.rage and run.combat.enemies.size() == 3)
	assert(run.combat.enemies[1].row != run.combat.enemies[2].row)
	run.combat.damage_enemy(boss,1,"bun")
	assert(run.combat.enemies.size() == 3)
	boss.summon = run.data.rules.boss_rage_summon_interval
	run.combat.step(1.0/60.0)
	assert(run.combat.enemies.size() == 5)
	run.director.cursor = run.director.events.size()
	run.combat.damage_enemy(boss,10000,"bun")
	run.advance(1.0/60.0)
	assert(run.state.phase == "battle", "summons prevent early victory")
	for enemy: Dictionary in run.combat.enemies.duplicate(): run.combat.damage_enemy(enemy,10000,"bun")
	run.advance(1.0/60.0)
	assert(run.state.phase == "prepare" and run.state.chapter_id == "kitchen_2" and run.state.wave == 1, "first boss continues the scene after summons clear")
	run.new_run(4)
	run.start()
	run.board.place("bun",2,0,false)
	run.combat.spawn("flour",2,run.data.waves[0])
	run.combat.enemies[0].x = 70.0
	run.combat.damage_enemy(run.combat.enemies[0],1000,"bun")
	assert(run.state.units[0].flour == 4.0)
	run.combat.spawn("gray",2,run.data.waves[0])
	run.combat.spawn("drummer",2,run.data.waves[0])
	run.combat.spawn("drummer",2,run.data.waves[0])
	assert(is_equal_approx(run.combat.movement_multiplier(run.combat.enemies[0],run.combat.enemies),1.2))
	print("PASS content: eight waves, generation, boss, summons, flour, drummer")
	quit()

# Preserve coverage of the pre-campaign immediate-summon fallback without mutating definitions.
# All shipped chapter bosses use telegraphs, checked in test_campaign_content / test_chapter_two.
func legacy_boss_wave(run: RunController) -> Resource:
	var wave: Resource = run.data.waves[7].duplicate(true)
	wave.stats.erase("boss")
	return wave
