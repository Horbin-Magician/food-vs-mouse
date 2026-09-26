class_name WaveDirector
extends RefCounted

var events: Array = []
var cursor: int = 0
var elapsed: float = 0.0

func begin(definition: Resource, rng: RandomNumberGenerator) -> void:
	events.clear()
	cursor = 0
	elapsed = 0.0
	if definition.stats.has("batches"):
		begin_batches(definition, rng)
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
		var before_boss: bool = i + 1 < composition.size() and composition[i+1] == "boss" and row == RunState.CENTER_ROW and previous == RunState.CENTER_ROW
		if i >= 3 and ((row == previous and streak >= 2) or before_boss):
			var alternatives: Array = definition.stats.rows.duplicate()
			alternatives.erase(previous)
			row = alternatives[rng.randi_range(0, alternatives.size() - 1)]
		streak = streak + 1 if row == previous else 1
		previous = row
		if composition[i] == "boss": row = RunState.CENTER_ROW
		events.append({"time": lerpf(5.0, definition.stats.duration * 0.7, float(i) / maxf(1.0, composition.size() - 1.0)), "id": composition[i], "row": row})

func begin_batches(definition: Resource, rng: RandomNumberGenerator) -> void:
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
			var row: int = RunState.CENTER_ROW if id == "boss" else lanes[batch.lanes[offset]]
			events.append({"time": batch.time + offset * batch.gap, "id": id, "row": row})
			previous = row
			index += 1

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
	return due

func finished() -> bool:
	return cursor >= events.size()
