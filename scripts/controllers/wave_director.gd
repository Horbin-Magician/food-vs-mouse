class_name WaveDirector
extends RefCounted

var events: Array = []
var cursor: int = 0
var elapsed: float = 0.0
var duration: float = 0.0
var transition_delay: float = 10.0
var last_spawn_elapsed: float = -1.0

func begin(definition: Resource, rng: RandomNumberGenerator) -> void:
	events.clear()
	cursor = 0
	elapsed = 0.0
	transition_delay = definition.transition_delay
	last_spawn_elapsed = -1.0
	duration = transition_delay
	if definition.stats.has("batches"):
		begin_batches(definition, rng)
		apply_spawn_rate(definition)
		return
	var rows: Array = definition.stats.rows.duplicate()
	var first: Array = []
	while not rows.is_empty():
		var index: int = rng.randi_range(0, rows.size() - 1)
		first.append(rows.pop_at(index))
	var previous: int = -1
	var streak: int = 0
	var composition: Array = definition.stats.composition
	for i: int in range(composition.size()):
		var row: int = first[i] if i < 3 else definition.stats.rows[rng.randi_range(0, definition.stats.rows.size() - 1)]
		var before_boss: bool = i + 1 < composition.size() and is_wave_boss(composition[i+1], definition) and row == RunState.CENTER_ROW and previous == RunState.CENTER_ROW
		if i >= 3 and ((row == previous and streak >= 2) or before_boss):
			var alternatives: Array = definition.stats.rows.duplicate()
			alternatives.erase(previous)
			row = alternatives[rng.randi_range(0, alternatives.size() - 1)]
		streak = streak + 1 if row == previous else 1
		previous = row
		if is_wave_boss(composition[i], definition): row = RunState.CENTER_ROW
		events.append({"time": lerpf(5.0, definition.stats.duration * 0.7, float(i) / maxf(1.0, composition.size() - 1.0)), "id": composition[i], "row": row})

	apply_spawn_rate(definition)

func apply_spawn_rate(definition: Resource) -> void:
	for event: Dictionary in events:
		event.time = 5.0 + (event.time - 5.0) / definition.spawn_rate
	if not events.is_empty(): duration = float(events.back().time) + transition_delay

func begin_batches(definition: Resource, rng: RandomNumberGenerator) -> void:
	if definition.stats.get("balanced_lanes", false):
		begin_balanced_batches(definition, rng)
		return
	var index: int = 0
	var previous: int = -1
	for batch: Dictionary in definition.stats.batches:
		var available: Array = definition.stats.rows.duplicate()
		var lanes: Array = []
		for slot: int in range(3):
			var choices: Array = available.duplicate()
			if slot == 0: choices.erase(previous)
			var row: int = choices[rng.randi_range(0, choices.size() - 1)]
			lanes.append(row)
			available.erase(row)
		for offset: int in range(batch.lanes.size()):
			var id: String = definition.stats.composition[index]
			var row: int = RunState.CENTER_ROW if is_wave_boss(id, definition) else lanes[batch.lanes[offset]]
			events.append({"time": batch.time + offset * batch.gap, "id": id, "row": row})
			previous = row
			index += 1

func begin_balanced_batches(definition: Resource, rng: RandomNumberGenerator) -> void:
	var selected: Dictionary = {}
	for row: int in definition.stats.rows: selected[row] = 0
	var index: int = 0
	var previous: int = -1
	var previous_batch: Array[Dictionary] = []
	for batch: Dictionary in definition.stats.batches:
		var available: Array = definition.stats.rows.duplicate()
		for excluded: int in batch.get("exclude_rows", []): available.erase(excluded)
		for event: Dictionary in previous_batch:
			if event.id in batch.get("avoid_previous_ids", []): available.erase(event.row)
		var lanes: Array[int] = []
		var boss_batch: bool = is_wave_boss(definition.stats.composition[index], definition)
		if boss_batch:
			lanes.append(RunState.CENTER_ROW)
		else:
			var slots: int = 1 if batch.lanes.size() == 1 else 3
			for slot: int in range(slots):
				var choices: Array = available.duplicate()
				if slot == 0: choices.erase(previous)
				var least: int = 2147483647
				var candidates: Array[int] = []
				for row: int in choices:
					if selected[row] < least:
						least = selected[row]
						candidates.clear()
					if selected[row] == least: candidates.append(row)
				assert(not candidates.is_empty(), "validated wave must have an available lane")
				var row: int = candidates[rng.randi_range(0, candidates.size() - 1)]
				lanes.append(row)
				available.erase(row)
				selected[row] += 1
		previous_batch.clear()
		for offset: int in range(batch.lanes.size()):
			var event: Dictionary = {"time": batch.time + offset * batch.gap, "id": definition.stats.composition[index], "row": lanes[batch.lanes[offset]]}
			events.append(event)
			previous_batch.append(event)
			previous = event.row
			index += 1

func is_wave_boss(id: String, definition: Resource) -> bool:
	return id == definition.stats.get("boss_id", "boss")

func warning_rows(lead_time: float = 5.0) -> Array[int]:
	var rows: Array[int] = []
	for i: int in range(cursor, events.size()):
		if events[i].time > elapsed + lead_time: break
		if not rows.has(events[i].row): rows.append(events[i].row)
	return rows

func advance(delta: float) -> Array:
	elapsed += delta
	var due: Array = []
	while cursor < events.size() and events[cursor].time <= elapsed:
		due.append(events[cursor])
		cursor += 1
	if finished() and last_spawn_elapsed < 0.0:
		last_spawn_elapsed = elapsed
		duration = elapsed + transition_delay
	return due

func finished() -> bool:
	return cursor >= events.size()

func can_complete(_enemy_count: int) -> bool:
	return finished() and last_spawn_elapsed >= 0.0 and elapsed + 0.000001 >= duration
