extends SceneTree

func _init() -> void:
	var data := Catalog.new()
	assert(data.validate().is_empty())
	assert(data.enemies.size() == 24)
	var ranks: Dictionary = {"normal":0,"elite":0,"boss":0}
	var modern: int = 0
	for id: String in data.enemies:
		var enemy: EnemyDef = data.enemies[id]
		ranks[data.enemy_rank(id)] += 1
		assert(enemy.art_id == id)
		assert(data.is_boss(id) == (enemy.rank == "boss"))
		assert(data.is_elite(id) == (enemy.rank == "elite"))
		if enemy.behavior_id != "legacy":
			modern += 1
			assert(not enemy.description.is_empty() and not enemy.story.is_empty() and not enemy.hint.is_empty())
	assert(ranks == {"normal":14,"elite":5,"boss":5} and modern == 16)
	assert(data.enemy_rank("unknown").is_empty() and not data.is_boss("unknown"))
	assert(data.enemies.boss.stats.hp == 2600 and data.enemies.elite.stats.hp == 520)
	assert(data.enemies.boss_quartermaster.skills.order_ids == ["spoon_skater","rivet_guard","dough_rat"])
	assert(data.enemies.boss_quartermaster.skills.rows == [2,4])
	for field: String in ["rank", "behavior_id", "art_id"]:
		var original: EnemyDef = data.enemies.spoon_skater
		var altered: EnemyDef = original.duplicate(true)
		data.enemies.spoon_skater = altered
		altered.set(field, "" if field == "art_id" else "invalid")
		assert(not data.validate().is_empty(), field)
		data.enemies.spoon_skater = original
	var skater: EnemyDef = data.enemies.spoon_skater
	var skills: Dictionary = skater.skills.duplicate(true)
	skater.skills.erase("windup")
	assert(not data.validate().is_empty())
	skater.skills = skills.duplicate(true)
	skater.skills.dash_speed = NAN
	assert(not data.validate().is_empty())
	skater.skills = skills
	var quarter: EnemyDef = data.enemies.boss_quartermaster
	var orders: Dictionary = quarter.skills.duplicate(true)
	quarter.skills.order_ids = ["boss", "rivet_guard", "dough_rat"]
	assert(not data.validate().is_empty())
	quarter.skills = orders.duplicate(true)
	quarter.skills.thresholds = [.3,.65]
	assert(not data.validate().is_empty())
	quarter.skills = orders
	var wave: Resource = data.chapter_waves("kitchen_2")[7]
	var stats: Dictionary = wave.stats.duplicate(true)
	wave.stats.boss_id = "gray"
	assert(not data.validate().is_empty())
	wave.stats = stats.duplicate(true)
	wave.stats.batches[0].exclude_rows = [0,1,2,3,4,5]
	assert(not data.validate().is_empty())
	wave.stats = stats
	assert(data.validate().is_empty())
	print("PASS enemy catalog: 24 definitions, 14/5/5 ranks, legacy preservation, 16 identities, finite order budget, malformed behavior/skills/rows rejected")
	quit()
