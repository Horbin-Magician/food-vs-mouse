extends SceneTree

func _init() -> void:
	var data := Catalog.new()
	var counts: Array = [10,16,22,26,36,42,50,31]
	for seed_value: int in range(300):
		for w: int in range(8):
			var a := RandomNumberGenerator.new()
			var b := RandomNumberGenerator.new()
			a.seed = seed_value
			b.seed = seed_value
			var director := WaveDirector.new()
			var copy := WaveDirector.new()
			director.begin(data.waves[w], a)
			copy.begin(data.waves[w], b)
			assert(director.events == copy.events and a.state == b.state)
			assert(director.events.size() == counts[w])
			var events: Array = director.events.duplicate(true)
			assert(events[0].row != events[1].row and events[0].row != events[2].row and events[1].row != events[2].row)
			for i: int in range(events.size()):
				assert(events[i].row in data.waves[w].stats.rows)
				if i > 0: assert(events[i].time > events[i-1].time)
				if i > 1: assert(not (events[i].row == events[i-1].row and events[i].row == events[i-2].row))
				if w < 2: assert(is_equal_approx(events[i].time, 5.0 + (lerpf(5, data.waves[w].stats.duration * 0.7, float(i)/(events.size()-1)) - 5.0) / 1.125))
			if w >= 2:
				var offset: int = 0
				for batch: Dictionary in data.waves[w].stats.batches:
					for i: int in range(batch.lanes.size()):
						for j: int in range(i):
							if batch.lanes[i] == batch.lanes[j]: assert(events[offset+i].row == events[offset+j].row)
					offset += batch.lanes.size()
				assert(is_equal_approx(events.back().time, 5.0 + (data.waves[w].stats.duration * (0.7 if w < 4 else 0.65) - 5.0) / 1.125))
			if w == 7: assert(events.back().id == "boss" and events.back().row == RunState.CENTER_ROW)
			assert(director.advance(0).is_empty())
			assert(director.advance(1000) == events)
			assert(director.finished() and director.advance(1000).is_empty())
	for invalid_rate: float in [0.0, -1.0, INF, NAN]:
		data.waves[0].spawn_rate = invalid_rate
		assert(not data.validate().is_empty())
	data.waves[0].spawn_rate = 1.125
	var warnings := WaveDirector.new()
	warnings.events = [{"time":1,"row":0},{"time":2,"row":1},{"time":3,"row":0},{"time":4,"row":2},{"time":5,"row":3},{"time":6,"row":4}]
	assert(warnings.warning_rows() == [0,1,2,3])
	warnings.advance(3)
	assert(warnings.warning_rows() == [2,3,4])
	var original: Dictionary = data.waves[2].stats.duplicate(true)
	data.waves[2].stats.batches[0].gap = 0
	assert(not data.validate().is_empty())
	data.waves[2].stats = original.duplicate(true)
	data.waves[2].stats.batches[0].lanes[0] = 9
	assert(not data.validate().is_empty())
	data.waves[2].stats = original.duplicate(true)
	data.waves[2].stats.batches.pop_back()
	assert(not data.validate().is_empty())
	data.waves[2].stats = original
	assert(data.validate().is_empty())
	print("PASS waves: 2400 schedules, seeded formations, timing, counts, warnings, invalid data, exactly-once dispatch")
	quit()
