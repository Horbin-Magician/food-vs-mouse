extends SceneTree

func _init() -> void:
	var data := Catalog.new()
	var waves: Array[Resource] = data.chapter_waves("kitchen_2")
	assert(waves.size() == 8)
	assert(waves[0].stats.hp_scale >= data.chapter_waves("kitchen_1")[7].stats.hp_scale)
	assert(waves[0].stats.composition.slice(0,3) == ["spoon_skater", "gray", "gray"])
	assert(waves[1].stats.composition.slice(0,3) == ["towel_scout", "gray", "gray"])
	for seed_value: int in range(100):
		for wave: Resource in waves:
			var random := RandomNumberGenerator.new()
			random.seed = seed_value
			var director := WaveDirector.new()
			director.begin(wave,random)
			assert(director.events.size() == wave.stats.composition.size())
			assert(director.events[0].time == 5 and is_equal_approx(director.events[1].time, 5.0 + 2.0/1.125) and is_equal_approx(director.events[2].time, 5.0 + 4.0/1.125))
			assert(is_equal_approx(director.events[3].time, 5.0 + 17.0/1.125))
			var initial_rows: Array = [director.events[0].row,director.events[1].row,director.events[2].row]
			assert(initial_rows[0] != initial_rows[1] and initial_rows[0] != initial_rows[2] and initial_rows[1] != initial_rows[2])
			assert(director.warning_rows() == [director.events[0].row])
			assert(director.advance(0).is_empty())
			var due: Array = director.advance(9)
			assert(due.size() == 3 and director.warning_rows().is_empty())
			assert(director.advance(10.9).is_empty())
			assert(not director.warning_rows().is_empty())
	var boss: EnemyDef = data.enemies[waves[7].stats.boss_id]
	assert(boss.id == "boss_windwhistle" and boss.rank == "boss" and boss.behavior_id == "windwhistle")
	assert(not waves[7].stats.has("boss") and not boss.skills.has("order_ids"))
	assert(waves[3].stats.composition[-1] == "spoon_captain")
	assert(data.enemies.spoon_skater.skills.segments == 1 and data.enemies.spoon_captain.skills.segments == 2)
	assert(data.enemies.towel_scout.skills.entrance_min == 768 and data.enemies.towel_scout.skills.entrance_max == 864)
	print("PASS chapter two: 800 schedules, safe introductions, five-second warnings, independent middle-lane boss, explicit skater/scout and elite resources")
	quit()
