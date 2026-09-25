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
const MOUSE_ACTION_TIME: float = 0.48
const HURT_TIME: float = 0.30
const DEATH_TIME: float = 0.72
const STRIDE_DISTANCE: float = 12.0
var corpses: Array[Dictionary] = []
var food_corpses: Array[Dictionary] = []
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
	corpses.clear()
	food_corpses.clear()
	time = 0.0
	phase = state.phase
	run.board.placed.connect(appear)
	run.board.moved.connect(move)
	run.combat.spawned.connect(appear)
	run.combat.acted.connect(act)
	run.combat.enemy_hurt.connect(hurt)
	run.combat.enemy_fallen.connect(fall)
	run.combat.food_hurt.connect(food_hurt)
	run.combat.food_fallen.connect(food_fall)

func entry(unit: Dictionary) -> Dictionary:
	if not entries.has(unit.uid):
		entries[unit.uid] = {"drop": 0.0, "action": 0.0, "move": 0.0, "from": Vector2.ZERO, "x": unit.get("x", 0.0), "stride": 0.0, "walking": false, "hurt": 0.0, "mouse": unit.has("x")}
	return entries[unit.uid]

func appear(unit: Dictionary) -> void:
	entry(unit).drop = DROP_TIME

func act(uid: int) -> void:
	# The entity can spawn and act between two presentation frames.
	if not entries.has(uid):
		for unit: Dictionary in state.units:
			if unit.uid == uid: entry(unit)
	if entries.has(uid): entries[uid].action = MOUSE_ACTION_TIME if entries[uid].mouse else ACTION_TIME

func hurt(unit: Dictionary) -> void:
	entry(unit).hurt = HURT_TIME

func fall(unit: Dictionary) -> void:
	var snapshot: Dictionary = unit.duplicate(true)
	snapshot["death_age"] = 0.0
	corpses.append(snapshot)

func food_hurt(unit: Dictionary) -> void:
	if unit.id == "bun": hurt(unit)

func food_fall(unit: Dictionary) -> void:
	if unit.id != "bun": return
	var snapshot: Dictionary = unit.duplicate(true)
	snapshot["death_age"] = 0.0
	food_corpses.append(snapshot)

func bun_frame(unit: Dictionary) -> Vector2i:
	if unit.has("death_age"):
		return Vector2i(mini(5, int(unit.death_age / DEATH_TIME * 6)), 4)
	var value: Dictionary = entry(unit)
	if value.hurt > 0:
		return Vector2i(sequence_frame(value.hurt, HURT_TIME), 3)
	if value.drop > 0:
		return Vector2i(sequence_frame(value.drop, DROP_TIME), 1)
	if value.move > 0:
		return Vector2i(sequence_frame(value.move, MOVE_TIME), 5)
	if value.action > 0:
		return Vector2i(sequence_frame(value.action, ACTION_TIME), 2)
	return Vector2i(posmod(int(time / 0.2) + unit.uid, 6), 0)

func sequence_frame(remaining: float, duration: float) -> int:
	return clampi(int((1.0 - remaining / duration) * 6), 0, 5)

func bun_pose(unit: Dictionary, foot: Vector2) -> Dictionary:
	if unit.has("death_age"):
		return {"shadow": foot, "foot": foot, "offset": Vector2.ZERO, "scale": Vector2.ONE, "angle": 0.0}
	# Translation follows the board; deformation is already painted in the frame.
	var value: Dictionary = entry(unit)
	var ground: Vector2 = foot
	if value.move > 0:
		ground = value.from.lerp(foot, smoothstep(0.0, 1.0, 1.0 - value.move / MOVE_TIME))
	var offset := Vector2.ZERO
	if value.drop > 0:
		var progress: float = 1.0 - value.drop / DROP_TIME
		offset.y = -30.0 * pow(1.0 - minf(progress / 0.6, 1.0), 2)
	return {"shadow": ground, "foot": moving_foot(value, foot), "offset": offset, "scale": Vector2.ONE, "angle": 0.0}

func mouse_frame(unit: Dictionary) -> Vector2i:
	if unit.has("death_age"):
		return Vector2i(mini(5, int(unit.death_age / DEATH_TIME * 6)), 3)
	var value: Dictionary = entry(unit)
	if value.hurt > 0:
		return Vector2i(clampi(int((1.0 - value.hurt / HURT_TIME) * 6), 0, 5), 2)
	if value.action > 0:
		return Vector2i(clampi(int((1.0 - value.action / MOUSE_ACTION_TIME) * 6), 0, 5), 1)
	if value.walking: return Vector2i(posmod(int(value.stride / TAU * 6), 6), 0)
	return Vector2i(5, 1)

func mouse_pose(unit: Dictionary, foot: Vector2) -> Dictionary:
	var offset := Vector2.ZERO
	var stretch := Vector2.ONE
	if not unit.has("death_age"):
		var value: Dictionary = entry(unit)
		if value.drop > 0:
			var progress: float = 1.0 - value.drop / DROP_TIME
			offset.y = -30.0 * pow(1.0 - minf(progress / 0.6, 1.0), 2)
			var squash: float = sin(clampf((progress - 0.5) / 0.5, 0.0, 1.0) * PI)
			stretch += Vector2(0.16, -0.14) * squash
	return {"shadow": foot, "foot": foot, "offset": offset, "scale": stretch, "angle": 0.0}

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
		corpses.clear()
		food_corpses.clear()
		for value: Dictionary in entries.values():
			value.action = 0.0
			value.drop = 0.0
			value.move = 0.0
			value.hurt = 0.0
		phase = state.phase
	for corpse: Dictionary in corpses.duplicate():
		corpse.death_age += delta
		if corpse.death_age >= DEATH_TIME: corpses.erase(corpse)
	for corpse: Dictionary in food_corpses.duplicate():
		corpse.death_age += delta
		if corpse.death_age >= DEATH_TIME: food_corpses.erase(corpse)
	time += delta
	var live: Dictionary = {}
	for unit: Dictionary in state.units + enemies:
		live[unit.uid] = true
		var value: Dictionary = entry(unit)
		for key: String in ["drop", "action", "move", "hurt"]:
			value[key] = maxf(0.0, value[key] - delta)
		if unit.has("x") and delta > 0:
			var distance: float = absf(unit.x - value.x)
			value.walking = distance > 0.0001
			value.stride = fmod(value.stride + distance * TAU / STRIDE_DISTANCE, TAU)
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
