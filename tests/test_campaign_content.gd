extends SceneTree

func _init() -> void:
	var data := Catalog.new()
	assert(data.validate().is_empty())
	var ids: Array = []
	var total: int = 0
	var previous_hp: float = 0.0
	var previous_damage: float = 0.0
	for chapter: ChapterDef in data.chapters.values():
		if not chapter.available: continue
		assert(chapter.waves.size() == 8)
		for index: int in range(8):
			var wave: Resource = chapter.waves[index]
			assert(wave.id not in ids)
			ids.append(wave.id)
			total += 1
			assert(wave.stats.composition.count("boss") == (1 if index == 7 else 0))
			assert(wave.stats.composition.count("elite") == (1 if index == 3 else 0))
			assert(wave.stats.hp_scale >= previous_hp and wave.stats.damage_scale >= previous_damage)
			previous_hp = wave.stats.hp_scale
			previous_damage = wave.stats.damage_scale
			if chapter.order > 1:
				assert(wave.stats.rows == [0,1,2,3,4,5,6])
				assert(wave.stats.composition.size() >= 36 and wave.stats.has("batches"))
			for seed_value: int in range(80):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value
				var director := WaveDirector.new()
				director.begin(wave, rng)
				var again := WaveDirector.new()
				rng.seed = seed_value
				again.begin(wave,rng)
				assert(again.events == director.events)
				assert(director.events[0].time >= 5.0)
				if chapter.order > 1:
					assert(is_equal_approx(director.events[-1].time, wave.stats.duration * 0.7))
				var previous: float = -1
				var recent: Array = []
				for event: Dictionary in director.events:
					assert(event.time > previous and event.row in wave.stats.rows)
					assert(event.time <= wave.stats.duration)
					previous = event.time
					recent.append(event.row)
					if recent.size() > 3: recent.pop_front()
					assert(recent.size() < 3 or recent[0] != recent[1] or recent[1] != recent[2])
				assert(director.advance(1000).size() == wave.stats.composition.size())
				assert(director.advance(1000).is_empty() and director.finished())
		if chapter.order == 1: continue
		var run := RunController.new()
		run.new_run(3)
		run.state.chapter_id = chapter.id
		run.state.wave = 8
		run.start()
		var wave: Resource = chapter.waves[7]
		run.combat.spawn("boss",3,wave)
		var boss: Dictionary = run.combat.enemies[0]
		run.combat.request_summons(wave.stats.boss.normal_id,boss)
		run.combat.step(wave.stats.boss.warning_seconds)
		assert(run.combat.enemies.size() == 3)
		assert(run.combat.enemies[1].id == wave.stats.boss.normal_id and run.combat.enemies[1].row == wave.stats.boss.rows[0])
		assert(run.combat.enemies[2].row == wave.stats.boss.rows[1])
	for index: int in range(8):
		assert(data.chapter_waves("kitchen_5")[index].stats.composition != data.chapter_waves("kitchen_4")[index].stats.composition)
	assert(total == 40)
	print("PASS campaign content: ",total," unique stages, continuous difficulty, elite/boss placement, seeded sequences, route streaks, once-only generation, configured summons")
	quit()
