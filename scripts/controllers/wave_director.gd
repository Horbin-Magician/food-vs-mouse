class_name WaveDirector
extends RefCounted

var events: Array = []
var cursor: int = 0
var elapsed: float = 0.0

func begin(definition: Resource, rng: RandomNumberGenerator) -> void:
	events.clear()
	cursor = 0
	elapsed = 0.0
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

func advance(delta: float) -> Array:
	elapsed += delta
	var due: Array = []
	while cursor < events.size() and events[cursor].time <= elapsed:
		due.append(events[cursor])
		cursor += 1
	return due

func finished() -> bool:
	return cursor >= events.size()
