class_name UnitAnimator
extends RefCounted

# x: breathing amplitude; y: cadence; z: action rotation. Pure visual tuning.
const PROFILES: Dictionary = {
	"bun": Vector3(0.025, 2.8, -0.13), "toast": Vector3(0.012, 1.8, 0.04),
	"pudding": Vector3(0.045, 3.2, 0.06), "tea": Vector3(0.018, 2.4, -0.10),
	"pepper": Vector3(0.022, 3.0, 0.18), "popcorn": Vector3(0.03, 2.6, -0.18),
	"noodles": Vector3(0.02, 2.2, -0.10), "garlic": Vector3(0.015, 2.0, 0.16),
	"gray": Vector3(0.02, 2.8, -0.14), "runner": Vector3(0.025, 3.8, -0.17),
	"lid": Vector3(0.012, 2.0, -0.10), "gnawer": Vector3(0.022, 3.0, -0.20),
	"drummer": Vector3(0.03, 2.6, -0.19), "flour": Vector3(0.025, 2.5, -0.14),
	"elite": Vector3(0.015, 1.8, -0.13), "boss": Vector3(0.018, 1.6, -0.22),
}
const DROP_TIME: float = 0.38
const MOVE_TIME: float = 0.32
const ACTION_TIME: float = 0.25
var entries: Dictionary = {}
var state: RunState
var projection: BoardProjection
var time: float = 0.0
var phase: String = ""

func bind(run: RunController, board_projection: BoardProjection) -> void:
	if state == run.state: return
	state = run.state
	projection = board_projection
	entries.clear()
	time = 0.0
	phase = state.phase
	run.board.placed.connect(appear)
	run.board.moved.connect(move)
	run.combat.spawned.connect(appear)
	run.combat.acted.connect(act)

func entry(unit: Dictionary) -> Dictionary:
	if not entries.has(unit.uid):
		entries[unit.uid] = {"drop": 0.0, "action": 0.0, "move": 0.0, "from": Vector2.ZERO, "x": unit.get("x", 0.0), "stride": 0.0, "walking": false}
	return entries[unit.uid]

func appear(unit: Dictionary) -> void:
	entry(unit).drop = DROP_TIME

func act(uid: int) -> void:
	# The entity can spawn and act between two presentation frames.
	if not entries.has(uid):
		for unit: Dictionary in state.units:
			if unit.uid == uid: entry(unit)
	if entries.has(uid): entries[uid].action = ACTION_TIME

func move(unit: Dictionary, from_row: int, from_col: int) -> void:
	var value: Dictionary = entry(unit)
	var old_foot: Vector2 = projection.foot(from_col * 96 + 48, from_row)
	value.from = moving_foot(value, old_foot)
	value.move = MOVE_TIME

func moving_foot(value: Dictionary, target: Vector2) -> Vector2:
	if value.move <= 0: return target
	var progress: float = 1.0 - value.move / MOVE_TIME
	return value.from.lerp(target, smoothstep(0.0, 1.0, progress)) - Vector2(0, sin(progress * PI) * 22)

func advance(delta: float, enemies: Array) -> void:
	if phase != state.phase:
		for value: Dictionary in entries.values():
			value.action = 0.0
			value.drop = 0.0
			value.move = 0.0
		phase = state.phase
	time += delta
	var live: Dictionary = {}
	for unit: Dictionary in state.units + enemies:
		live[unit.uid] = true
		var value: Dictionary = entry(unit)
		for key: String in ["drop", "action", "move"]:
			value[key] = maxf(0.0, value[key] - delta)
		if unit.has("x") and delta > 0:
			var distance: float = absf(unit.x - value.x)
			value.walking = distance > 0.0001
			value.stride += distance * 0.24
			value.x = unit.x
	for uid: int in entries.keys():
		if not live.has(uid): entries.erase(uid)

func pose(unit: Dictionary, target: Vector2) -> Dictionary:
	var value: Dictionary = entry(unit)
	var profile: Vector3 = PROFILES[unit.id]
	var breath: float = sin(time * profile.y + unit.uid * 1.7) * profile.x
	var stretch: Vector2 = Vector2(1.0 - breath * 0.5, 1.0 + breath)
	var offset: Vector2 = Vector2.ZERO
	var angle: float = 0.0
	if unit.has("x") and value.walking:
		var step: float = sin(value.stride)
		offset.y = -absf(step) * 4.0
		angle = step * 0.045
		stretch += Vector2(-absf(step), absf(step)) * 0.025
	if value.action > 0:
		var pulse: float = sin((1.0 - value.action / ACTION_TIME) * PI)
		angle += profile.z * pulse
		stretch += Vector2(0.10, -0.09) * pulse
		offset.x += (-7.0 if unit.has("x") else (-5.0 if unit.id not in ["pepper", "garlic"] else 8.0)) * pulse
		if unit.id == "pudding": offset.y -= 12.0 * pulse
	if unit.id == "toast" and unit.get("flash", 0.0) > 0:
		stretch += Vector2(0.08, -0.08) * unit.flash / 0.15
	if value.drop > 0:
		var progress: float = 1.0 - value.drop / DROP_TIME
		offset.y -= 30.0 * pow(1.0 - minf(progress / 0.6, 1.0), 2)
		var squash: float = sin(clampf((progress - 0.5) / 0.5, 0.0, 1.0) * PI)
		stretch += Vector2(0.16, -0.14) * squash
	var ground: Vector2 = target
	if value.move > 0:
		ground = value.from.lerp(target, smoothstep(0.0, 1.0, 1.0 - value.move / MOVE_TIME))
	return {"shadow": ground, "foot": moving_foot(value, target), "offset": offset, "scale": stretch, "angle": angle}
