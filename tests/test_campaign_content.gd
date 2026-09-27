extends SceneTree

const NEW_IDS: Dictionary = {
	2: ["spoon_skater", "towel_scout"], 3: ["rivet_guard", "tong_breaker"],
	4: ["vinegar_spitter", "dough_rat"], 5: ["ration_keeper", "skewer_lancer"]
}
const COUNTS: Dictionary = {
	2: [[16,0,12,0], [10,12,8,0], [14,12,0,6], [14,10,8,0], [12,16,0,6], [16,14,6,0], [18,14,0,6], [14,10,4,0]],
	3: [[18,0,10,0], [10,12,8,0], [16,10,0,6], [14,12,8,0], [14,14,0,6], [18,12,6,0], [18,14,0,6], [16,8,4,0]],
	4: [[16,0,12,0], [10,12,8,0], [12,14,6,0], [12,14,8,0], [12,16,0,6], [16,14,6,0], [16,16,0,6], [12,12,4,0]],
	5: [[16,0,14,0,0], [10,14,8,0,0], [12,16,0,6,0], [14,14,8,0,0], [12,18,0,0,6], [14,18,0,6,0], [16,18,0,0,6], [12,14,4,0,0]]
}
const OLD_IDS: Dictionary = {2: ["gray", "runner"], 3: ["gray", "gnawer"], 4: ["gray", "flour"], 5: ["gray", "rivet_guard", "dough_rat"]}
const BOSSES: Array[String] = ["boss", "boss_windwhistle", "boss_ironpot", "boss_starter", "boss_quartermaster"]
const ELITES: Array[String] = ["elite", "spoon_captain", "rivet_foreman", "vinegar_cellarer", "skewer_marshal"]

func _init() -> void:
	var data := Catalog.new()
	assert(data.validate().is_empty())
	var ids: Array[String] = []
	var ordinary_total: int = 0
	var previous_hp: float = 0.0
	var previous_damage: float = 0.0
	for chapter: ChapterDef in data.chapters.values():
		assert(chapter.available and chapter.waves.size() == 8)
		for index: int in range(8):
			var wave: Resource = chapter.waves[index]
			var composition: Array = wave.stats.composition
			assert(wave.id not in ids)
			ids.append(wave.id)
			assert(composition.count(BOSSES[chapter.order-1]) == (1 if index == 7 else 0))
			assert(composition.count(ELITES[chapter.order-1]) == (1 if index == 3 else 0))
			assert(wave.stats.hp_scale >= previous_hp and wave.stats.damage_scale >= previous_damage)
			previous_hp = wave.stats.hp_scale
			previous_damage = wave.stats.damage_scale
			if chapter.order > 1:
				assert(wave.stats.rows == [0,1,2,3,4,5,6] and wave.stats.balanced_lanes)
				assert(not wave.stats.has("boss"))
				var columns: Array = NEW_IDS[chapter.order] + OLD_IDS[chapter.order]
				var normal: int = 0
				for c: int in range(columns.size()):
					assert(composition.count(columns[c]) == COUNTS[chapter.order][index][c], wave.id + ": " + columns[c])
					normal += COUNTS[chapter.order][index][c]
				assert(composition.size() == normal + (1 if index in [3,7] else 0))
				assert((COUNTS[chapter.order][index][0] + COUNTS[chapter.order][index][1]) * 2 >= normal)
				ordinary_total += normal
				if index < 2:
					assert(composition.slice(0,3) == [NEW_IDS[chapter.order][index], "gray", "gray"])
				if index == 7: assert(wave.stats.boss_id == BOSSES[chapter.order-1])
			for seed_value: int in range(80):
				verify_schedule(wave, chapter.order, seed_value)
	assert(ids.size() == 40 and ordinary_total == 1054)
	assert(data.chapters.kitchen_3.title == "铁锅围城" and data.chapters.kitchen_4.title == "发酵暗巷" and data.chapters.kitchen_5.title == "黎明粮道")
	verify_teaching_combinations(data)
	print("PASS campaign content: 40 unique stages, 1054 redesigned ordinary enemies, exact species quotas, 3200 seeded schedules, seven-lane coverage, finite special entries, teaching formations")
	quit()

func verify_schedule(wave: Resource, chapter_order: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var director := WaveDirector.new()
	director.begin(wave, rng)
	assert(wave.spawn_rate == 1.125)
	var base_wave: Resource = wave.duplicate(true)
	base_wave.spawn_rate = 1.0
	var base_rng := RandomNumberGenerator.new()
	base_rng.seed = seed_value
	var base := WaveDirector.new()
	base.begin(base_wave, base_rng)
	assert(base_rng.state == rng.state)
	for index: int in range(director.events.size()):
		assert(director.events[index].id == base.events[index].id and director.events[index].row == base.events[index].row)
		assert(is_equal_approx(director.events[index].time, 5.0 + (base.events[index].time - 5.0) / 1.125))
	var old_wave: Resource = wave.duplicate(true)
	old_wave.spawn_rate = 1.5
	var old_rng := RandomNumberGenerator.new()
	old_rng.seed = seed_value
	var old := WaveDirector.new()
	old.begin(old_wave, old_rng)
	assert(old_rng.state == rng.state and old.events.size() == director.events.size())
	for index: int in range(director.events.size()):
		assert(director.events[index].id == old.events[index].id and director.events[index].row == old.events[index].row)
		assert(is_equal_approx(director.events[index].time - 5.0, (old.events[index].time - 5.0) * 4.0 / 3.0))
		if index > 0:
			assert(is_equal_approx(director.events[index].time - director.events[index-1].time, (old.events[index].time - old.events[index-1].time) * 4.0 / 3.0))
	assert(is_equal_approx(director.duration, director.events.back().time + 10.0))
	var random_state: int = rng.state
	var again := WaveDirector.new()
	rng.seed = seed_value
	again.begin(wave, rng)
	assert(again.events == director.events and random_state == rng.state)
	assert(director.events.size() == wave.stats.composition.size())
	assert(director.events[0].time == 5.0)
	assert(director.events[0].row != director.events[1].row and director.events[0].row != director.events[2].row and director.events[1].row != director.events[2].row)
	var previous: float = -1
	var recent: Array = []
	for event: Dictionary in director.events:
		assert(event.time > previous and event.row in wave.stats.rows)
		assert(event.time <= wave.stats.duration)
		previous = event.time
		recent.append(event.row)
		if recent.size() > 3: recent.pop_front()
		assert(recent.size() < 3 or recent[0] != recent[1] or recent[1] != recent[2])
	if chapter_order > 1:
		assert(is_equal_approx(director.events[1].time, 5.0 + 2.0/1.125) and is_equal_approx(director.events[2].time, 5.0 + 4.0/1.125) and is_equal_approx(director.events[3].time, 5.0 + 17.0/1.125))
		assert(is_equal_approx(director.events[-1].time, 5.0 + (wave.stats.duration * .7 - 5.0)/1.125))
		var covered: Dictionary = {}
		for event: Dictionary in director.events.slice(0,14): covered[event.row] = true
		assert(covered.size() == 7)
		if wave.stats.has("boss_id"):
			assert(director.events[-1].row == RunState.CENTER_ROW)
			assert(is_equal_approx(director.events[-1].time-director.events[-2].time,8.0/1.125))
		var offset: int = 0
		var previous_batch: Array = []
		for batch: Dictionary in wave.stats.batches:
			var batch_events: Array = director.events.slice(offset, offset + batch.lanes.size())
			for event: Dictionary in batch_events: assert(event.row not in batch.get("exclude_rows", []))
			if batch.has("avoid_previous_ids"):
				for event: Dictionary in previous_batch:
					if event.id in batch.avoid_previous_ids: assert(event.row != batch_events[0].row)
			previous_batch = batch_events
			offset += batch.lanes.size()
	assert(director.advance(1000).size() == wave.stats.composition.size())
	assert(director.advance(1000).is_empty() and director.finished())

func verify_teaching_combinations(data: Catalog) -> void:
	# The first breaker combination keeps one heavy bite, followed by a harmless mouse on its lane.
	var breaker_wave: Resource = data.chapter_waves("kitchen_3")[1]
	var breaker_intro: Array = batch_composition(breaker_wave, 2)
	assert(breaker_intro.count("tong_breaker") == 1)
	assert(has_same_lane_followup(breaker_wave, 2, "tong_breaker", "gray"))
	# Ration support is introduced deliberately after the lancer's independent early batches.
	var lancer_wave: Resource = data.chapter_waves("kitchen_5")[1]
	for batch_index: int in range(3):
		assert(not has_same_lane_followup(lancer_wave, batch_index, "skewer_lancer", "ration_keeper"))
	assert(has_same_lane_followup(lancer_wave, 3, "skewer_lancer", "ration_keeper"))
	assert(data.chapter_waves("kitchen_5")[0].stats.composition.slice(3,8) == ["gray", "ration_keeper", "ration_keeper", "ration_keeper", "ration_keeper"])
	for index: int in [2,4,5,6]:
		var wave: Resource = data.chapter_waves("kitchen_5")[index]
		var guest: String = "rivet_guard" if index in [2,5] else "dough_rat"
		var offset: int = 0
		for b: int in range(wave.stats.batches.size()):
			var size: int = wave.stats.batches[b].lanes.size()
			assert(wave.stats.composition.slice(offset, offset+size).count(guest) == (2 if b in [1,2,3] else 0))
			offset += size
	for index: int in [4,6]:
		var wave: Resource = data.chapter_waves("kitchen_4")[index]
		var offset: int = 0
		for batch: Dictionary in wave.stats.batches:
			for i: int in range(batch.lanes.size()):
					if wave.stats.composition[offset+i] == "flour": assert(batch.lanes[i] == 2)
			offset += batch.lanes.size()

func batch_composition(wave: Resource, batch_index: int) -> Array:
	var offset: int = 0
	for index: int in range(batch_index): offset += wave.stats.batches[index].lanes.size()
	return wave.stats.composition.slice(offset, offset + wave.stats.batches[batch_index].lanes.size())

func has_same_lane_followup(wave: Resource, batch_index: int, leader: String, follower: String) -> bool:
	var composition: Array = batch_composition(wave, batch_index)
	var lanes: Array = wave.stats.batches[batch_index].lanes
	for index: int in range(composition.size()):
		if composition[index] != leader: continue
		for next: int in range(index + 1, composition.size()):
			if lanes[next] != lanes[index]: continue
			if composition[next] == follower: return true
			break
	return false
