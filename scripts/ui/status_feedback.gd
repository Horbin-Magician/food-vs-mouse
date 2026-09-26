class_name StatusFeedback
extends RefCounted

# Presentation only: durations, colors and sizes never enter combat calculations.
const MAX_EFFECTS: int = 80
const BADGES: Texture2D = preload("res://assets/art/status_badges.svg")
const BADGE_INDEX: Dictionary = {"haste": 0, "power": 1, "drum": 2, "slow": 3, "burn": 4, "flour": 5, "armor": 6, "crust": 7, "rage": 8, "pressure": 9}
const DURATIONS: Dictionary = {"summon": 1.1, "reinforce": 1.1, "rage": 0.85, "flour": 0.8, "popcorn": 0.5, "steam": 0.5, "melee": 0.3, "cold_spice": 0.4, "produce": 0.6, "recycle": 0.6, "heal": 0.7}
const COLORS: Dictionary = {"haste": Color("78f3c2"), "power": Color("ffd478"), "drum": Color("d8a1ff"), "slow": Color("8ce7ff"), "burn": Color("ff934d"), "flour": Color("eee4ce"), "armor": Color("b0d8ed"), "crust": Color("ffe0a0"), "rage": Color("ff6c75"), "pressure": Color("c0f9ff")}
const NAMES: Dictionary = {"haste": "蒜香攻速", "power": "早餐伤害", "drum": "鼓舞移速", "slow": "减速", "burn": "灼烧", "flour": "面粉", "armor": "锅盖护甲", "crust": "酥脆外壳", "rage": "狂暴", "pressure": "高压就绪"}
var effects: Array[Dictionary] = []
var statuses: Dictionary = {}
var time: float = 0.0
var phase: String = ""
var state: RunState
var combat: CombatController
var board: BoardController
var recipes: RecipeSystem
var projection: BoardProjection
var dense: bool = false
var halo_cache: Dictionary = {}

func bind(run: RunController, board_projection: BoardProjection) -> void:
	if state == run.state: return
	if combat != null and combat.skill_used.is_connected(on_skill): combat.skill_used.disconnect(on_skill)
	if board != null and board.healed.is_connected(on_heal): board.healed.disconnect(on_heal)
	effects.clear()
	statuses.clear()
	halo_cache.clear()
	time = 0.0
	state = run.state
	combat = run.combat
	board = run.board
	recipes = run.recipes
	projection = board_projection
	phase = state.phase
	combat.skill_used.connect(on_skill)
	board.healed.connect(on_heal)
	refresh()

func point(unit: Dictionary) -> Vector2:
	return projection.foot(float(unit.x) if unit.has("x") else unit.col * 96.0 + 48.0, unit.row)

func on_skill(id: String, source: Dictionary, targets: Array) -> void:
	if not DURATIONS.has(id): return
	var destinations: Array[Vector2] = []
	for target: Dictionary in targets: destinations.append(point(target))
	effects.append({"id": id, "uid": source.uid, "origin": point(source), "targets": destinations, "radius": source.get("radius", 0.0) * BoardProjection.CANVAS_SIZE.x / RunState.BOARD_WIDTH, "age": 0.0})
	if effects.size() > MAX_EFFECTS: effects.pop_front()

func on_heal(unit: Dictionary) -> void:
	on_skill("heal", unit, [])

func advance(delta: float) -> void:
	if phase != state.phase:
		# Healing is emitted during settlement, immediately before entering prepare.
		effects = effects.filter(func(effect: Dictionary) -> bool: return state.phase == "prepare" and effect.id == "heal")
		phase = state.phase
	time += delta
	for effect: Dictionary in effects.duplicate():
		effect.age += delta
		if effect.age >= DURATIONS[effect.id]: effects.erase(effect)
	refresh()

func refresh() -> void:
	dense = combat.enemies.size() > 45
	statuses.clear()
	for unit: Dictionary in state.units:
		var active: Array[String] = []
		var attacking: bool = combat.data.foods[unit.id].stats.kind in ["shot", "melee"]
		if attacking and recipes.adjacent(unit, "garlic"): active.append("haste")
		if attacking and recipes.has("breakfast") and recipes.adjacent(unit, "pudding"): active.append("power")
		if unit.flour > 0 or unit.get("proof_time", 0.0) > 0: active.append("flour")
		if unit.id == "toast" and recipes.has("crust"): active.append("crust")
		if unit.id == "bun" and recipes.has("pressure") and (unit.attacks + 1) % int(recipes.value("pressure", "every")) == 0: active.append("pressure")
		statuses[unit.uid] = active
	var drummers: Array = combat.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.id == "drummer")
	for enemy: Dictionary in combat.enemies:
		var active: Array[String] = []
		if combat.is_drummer_boosted(enemy, drummers): active.append("drum")
		if enemy.slow_time > 0: active.append("slow")
		if enemy.burn_time > 0: active.append("burn")
		if enemy.armor > 0: active.append("armor")
		if enemy.rage: active.append("rage")
		statuses[enemy.uid] = active

func description(unit: Dictionary) -> String:
	var names: PackedStringArray = []
	if unit.id == "garlic": names.append("攻速光环来源")
	if unit.id == "pudding" and recipes.has("breakfast"): names.append("早餐光环来源")
	if unit.id == "drummer": names.append("鼓舞光环来源")
	for id: String in statuses.get(unit.uid, []):
		var title: String = NAMES[id]
		if id == "armor": title = "护甲 ×%d" % unit.armor
		if id in ["slow", "burn", "flour"]:
			var remaining: float = unit.get(id + "_time", unit.get("flour", 0.0))
			if id == "flour":
				remaining = maxf(remaining, float(unit.get("proof_time", 0.0)))
				if unit.get("proof_time", 0.0) > 0: title = "醒面攻速 -25%"
			title += " %.1fs" % remaining
		names.append(title)
	return " · ".join(names)

func cast_pose(unit: Dictionary, pose: Dictionary) -> Dictionary:
	for effect: Dictionary in effects:
		if effect.uid == unit.uid and effect.id in ["summon", "reinforce"]:
			var lift: float = sin(clampf(effect.age / 0.6, 0.0, 1.0) * PI)
			pose.offset += Vector2(0, -8.0 * lift)
			pose.angle -= 0.07 * lift
			break
	return pose

static func ring(canvas: Node2D, center: Vector2, radius: Vector2, color: Color, width: float = 2.0, start: float = 0.0, sweep: float = TAU) -> void:
	var points: PackedVector2Array = []
	var segments: int = maxi(6, ceili(absf(sweep) / TAU * 24))
	for i: int in range(segments + 1):
		var angle: float = start + sweep * i / segments
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_polyline(points, color, width, true)

static func star(canvas: Node2D, center: Vector2, size: float, color: Color) -> void:
	# Faded subpixel polygons can collapse after float rounding at screen coordinates.
	if size < 0.8 or color.a < 0.02: return
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size), center + Vector2(size * 0.3, -size * 0.3), center + Vector2(size, 0), center + Vector2(size * 0.3, size * 0.3), center + Vector2(0, size), center + Vector2(-size * 0.3, size * 0.3), center + Vector2(-size, 0), center + Vector2(-size * 0.3, -size * 0.3)]), color)

func compact_halo(active: Array) -> Texture2D:
	var key: String = ",".join(active)
	if halo_cache.has(key): return halo_cache[key]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="56" viewBox="0 0 64 28"><g fill="none" stroke-width="2" opacity="0.8">'
	for i: int in range(active.size()):
		var start: float = TAU * i / active.size()
		var end: float = start + TAU / active.size() * 0.88
		var a: Vector2 = Vector2(32, 14) + Vector2(cos(start) * 27, sin(start) * 10)
		var b: Vector2 = Vector2(32, 14) + Vector2(cos(end) * 27, sin(end) * 10)
		svg += '<path stroke="#%s" d="M%.3f %.3f A27 10 0 %d 1 %.3f %.3f"/>' % [COLORS[active[i]].to_html(false), a.x, a.y, 1 if end - start > PI else 0, b.x, b.y]
	svg += '</g></svg>'
	var pixels := Image.new()
	pixels.load_svg_from_string(svg)
	var texture: ImageTexture = ImageTexture.create_from_image(pixels)
	# Cache combinations, never instances; evict old combinations if content expands.
	if halo_cache.size() >= 64: halo_cache.erase(halo_cache.keys()[0])
	halo_cache[key] = texture
	return texture

func draw_ground(canvas: Node2D, unit: Dictionary, foot: Vector2) -> void:
	if unit.has("death_age") or state == null: return
	var active: Array = statuses.get(unit.uid, [])
	var pulse: float = sin(time * 3.0 + unit.uid) * 0.5 + 0.5
	var source: String = ""
	if unit.id == "garlic": source = "haste"
	if unit.id == "pudding" and recipes.has("breakfast"): source = "power"
	if unit.id == "drummer": source = "drum"
	if not source.is_empty():
		var tint: Color = COLORS[source]
		ring(canvas, foot, Vector2(32, 11), Color(tint, 0.65), 2.0)
		ring(canvas, foot, Vector2(36, 14), Color(tint, 0.45), 1.5, time, PI * 1.5)
		for i: int in range(4):
			var angle: float = i * PI * 0.5 + (time * 0.6 if source == "power" else 0.0)
			star(canvas, foot + Vector2(cos(angle) * 32, sin(angle) * 11), 3.5 + pulse, tint)
	if dense:
		if not active.is_empty(): canvas.draw_texture_rect(compact_halo(active), Rect2(foot - Vector2(32, 14), Vector2(64, 28)), false)
		return
	for index: int in range(active.size()):
		var id: String = active[index]
		var tint: Color = COLORS[id]
		var radius := Vector2(23 + index * 3, 7 + index * 2)
		ring(canvas, foot, radius, Color(tint, 0.22 + pulse * 0.18), 5.0)
		ring(canvas, foot, radius, Color(tint, 0.8), 1.3, time * 0.8 + index, PI * 1.5)
		if id == "slow":
			for side: int in [-1, 1]:
				var p: Vector2 = foot + Vector2(side * 23, 0)
				canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 2), p + Vector2(-2, -13), p + Vector2(5, -5), p + Vector2(5, 3)]), Color(tint, 0.7))
		if id == "rage":
			var spikes: PackedVector2Array = []
			for i: int in range(25):
				var angle: float = i / 24.0 * TAU
				spikes.append(foot + Vector2(cos(angle) * (36 if i % 2 == 0 else 29), sin(angle) * (13 if i % 2 == 0 else 10)))
			canvas.draw_polyline(spikes, Color(tint, 0.8), 2.0, true)

func draw_status(canvas: Node2D, unit: Dictionary, foot: Vector2, height: float) -> void:
	if unit.has("death_age") or state == null: return
	var active: Array = statuses.get(unit.uid, [])
	for index: int in range(active.size()):
		var id: String = active[index]
		var tint: Color = COLORS[id]
		var center: Vector2 = foot + Vector2((index - (active.size() - 1) * 0.5) * 16, 18)
		canvas.draw_texture_rect_region(BADGES, Rect2(center - Vector2.ONE * 7.5, Vector2.ONE * 15), Rect2(BADGE_INDEX[id] * 32, 0, 32, 32))
		if dense: continue
		if id in ["armor", "crust"]:
			var shield: PackedVector2Array = [foot + Vector2(-29, -height * 0.68), foot + Vector2(0, -height * 0.83), foot + Vector2(29, -height * 0.68), foot + Vector2(25, -12), foot + Vector2(0, -1), foot + Vector2(-25, -12), foot + Vector2(-29, -height * 0.68)]
			canvas.draw_polyline(shield, Color(tint, 0.6), 1.6, true)
			if id == "armor":
				for i: int in range(int(unit.armor)):
					canvas.draw_circle(foot + Vector2(32, -13 - i * 7), 2.4, tint)
		if id in ["burn", "rage"]:
			for i: int in range(4):
				var rise: float = fposmod(time * 1.8 + i * 0.27 + unit.uid * 0.13, 1.0)
				var p: Vector2 = foot + Vector2((-1 if i % 2 == 0 else 1) * (21 + i), -5 - rise * 27)
				star(canvas, p, 4 * (1.0 - rise) + 1, Color(tint, 1.0 - rise))
		if id == "flour":
			for i: int in range(5):
				var p: Vector2 = foot + Vector2(sin(time * 1.5 + i * 2) * 21, -height * 0.65 + cos(time * 2 + i) * 5)
				canvas.draw_circle(p, 2.5 + i % 2, Color(tint, 0.7))
		if id == "pressure":
			for i: int in range(3):
				var p: Vector2 = foot + Vector2(-10 + i * 10, -height * 0.7 - sin(time * 3 + i) * 3)
				canvas.draw_arc(p, 3 + i, 0, TAU, 16, Color(tint, 0.8), 1.4, true)
		if id == "drum":
			for i: int in range(2):
				var p: Vector2 = foot + Vector2(25 + i * 7 + sin(time * 4) * 2, -15)
				canvas.draw_polyline(PackedVector2Array([p + Vector2(4, -5), p, p + Vector2(4, 5)]), Color(tint, 0.7), 2, true)

func draw_effects(canvas: Node2D) -> void:
	for effect: Dictionary in effects:
		var progress: float = effect.age / DURATIONS[effect.id]
		var alpha: float = 1.0 - smoothstep(0.45, 1.0, progress)
		var origin: Vector2 = effect.origin
		if effect.id in ["summon", "reinforce"]:
			draw_summon(canvas, effect, progress, alpha)
		elif effect.id == "rage":
			var tint: Color = Color(COLORS.rage, alpha)
			ring(canvas, origin, Vector2(28 + progress * 65, 10 + progress * 22), tint, 3)
			for i: int in range(10):
				var v: Vector2 = Vector2.from_angle(i * TAU / 10.0)
				star(canvas, origin + Vector2(v.x, v.y * 0.5) * (26 + progress * 70) - Vector2(0, 18), 5 * alpha, tint)
			caption(canvas, origin + Vector2(0, -97 - progress * 8), "狂暴", tint)
		elif effect.id in ["flour", "steam", "popcorn"]:
			var tint: Color = COLORS.flour if effect.id == "flour" else (COLORS.pressure if effect.id == "steam" else COLORS.power)
			var radius: float = maxf(20, effect.radius) * (0.3 + 0.7 * progress)
			ring(canvas, origin - Vector2(0, 12), Vector2(radius, 15 + progress * 8), Color(tint, alpha * 0.8), 2)
			for i: int in range(10):
				var a: float = i * TAU / 10.0
				var p: Vector2 = origin + Vector2(cos(a) * radius, sin(a) * 19 - 18 - progress * 9)
				if effect.id == "popcorn": star(canvas, p, (4 + i % 3) * alpha, Color(tint, alpha))
				else:
					canvas.draw_circle(p, (7 + i % 3 * 3) * (0.7 + progress), Color(tint, alpha * 0.23))
					ring(canvas, p, Vector2.ONE * (5 + i % 3), Color(tint, alpha * 0.5), 1.2, progress + i, PI)
		elif effect.id == "melee":
			if effect.targets.is_empty(): continue
			var tip: Vector2 = effect.targets[0] - Vector2(0, 27)
			var start: Vector2 = origin - Vector2(0, 23)
			canvas.draw_line(start, start.lerp(tip, minf(progress * 3, 1.0)), Color(COLORS.haste, alpha * 0.6), 3, true)
			ring(canvas, tip, Vector2(16, 23), Color(COLORS.haste, alpha), 3, -PI * 0.65 + progress, PI * 0.9)
		elif effect.id == "cold_spice":
			for i: int in range(6):
				var p: Vector2 = origin - Vector2(0, 25) + Vector2.from_angle(i * TAU / 6.0) * (8 + 25 * progress)
				star(canvas, p, 4 * alpha, Color(COLORS.slow if i % 2 == 0 else COLORS.burn, alpha))
		else:
			var tint: Color = COLORS.haste if effect.id == "heal" else COLORS.power
			ring(canvas, origin, Vector2(20 + progress * 25, 8 + progress * 9), Color(tint, alpha), 2)
			for i: int in range(3):
				var p: Vector2 = origin + Vector2((i - 1) * 17, -17 - progress * 35 - i % 2 * 9)
				if effect.id == "heal":
					canvas.draw_line(p - Vector2(4, 0), p + Vector2(4, 0), Color(tint, alpha), 2, true)
					canvas.draw_line(p - Vector2(0, 4), p + Vector2(0, 4), Color(tint, alpha), 2, true)
				else: star(canvas, p, 5 * alpha, Color(tint, alpha))

func draw_summon(canvas: Node2D, effect: Dictionary, progress: float, alpha: float) -> void:
	var heavy: bool = effect.id == "reinforce"
	var tint: Color = COLORS.rage if heavy else COLORS.drum
	var origin: Vector2 = effect.origin - Vector2(0, 48)
	for i: int in range(2):
		ring(canvas, origin, Vector2(18 + progress * 28 + i * 8, 12 + progress * 18 + i * 5), Color(tint, alpha * 0.65), 2, -PI, PI * 1.7)
	caption(canvas, origin + Vector2(0, -33 - progress * 8), "重装援军" if heavy else "召唤援军", Color(tint, alpha))
	for destination: Vector2 in effect.targets:
		var path: PackedVector2Array = []
		for i: int in range(25):
			var t: float = i / 24.0
			path.append(origin.lerp(destination - Vector2(0, 20), t) - Vector2(0, sin(t * PI) * 42))
		canvas.draw_polyline(path, Color(tint, alpha * 0.25), 2, true)
		var tip: int = mini(24, int(progress * 2.8 * 24))
		star(canvas, path[tip], 6 * alpha, Color("fff2cf", alpha))
		var open: float = minf(1.0, 0.35 + progress * 3)
		ring(canvas, destination, Vector2(33, 13) * open, Color(tint, alpha), 3)
		ring(canvas, destination, Vector2(25, 9) * open, Color("ffe6ac", alpha * 0.8), 1.4, progress * 4, TAU * 0.8)
		for side: int in [-1, 1]:
			var p: Vector2 = destination + Vector2(side * 29 * open, 0)
			canvas.draw_line(p, p - Vector2(0, 58 * open), Color(tint, alpha * 0.2), 7, true)
			canvas.draw_line(p, p - Vector2(0, 58 * open), Color(tint, alpha * 0.8), 1.5, true)
			star(canvas, p - Vector2(0, 45 * open), 4 * alpha, Color("ffe6ac", alpha))

static func caption(canvas: Node2D, center: Vector2, title: String, tint: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var p: Vector2 = center - Vector2(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, 0)
	canvas.draw_string_outline(font, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0.07, 0.12, 0.15, tint.a))
	canvas.draw_string(font, p, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tint)
