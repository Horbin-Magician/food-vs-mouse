class_name EnemySkillFeedback
extends RefCounted

# Read-only presentation. Telegraph lifetime belongs exclusively to combat.
const TINTS: Dictionary = {"dash": Color("7de0d0"), "switch": Color("9be7ff"), "heavy": Color("eab675"), "acid": Color("b6cc70"), "proof": Color("edd9f1"), "ration": Color("81dec6"), "order": Color("f3d087")}
const LABELS: Dictionary = {"dash": "起跑", "switch": "换路", "heavy": "重砸", "acid": "酸滴", "proof": "醒面", "ration": "配给", "order": "粮签"}
const IMPACTS: Array[String] = ["dash", "switch", "heavy", "acid", "proof", "ration", "order", "shield", "exposed", "armor_break", "skewer", "order_success", "order_failed"]
const BOSS_RECT := Rect2(1028, 112, 230, 240)
# Shared read-only styles; building StyleBoxFlat inside draw calls allocates every frame.
var boss_panel_style: StyleBoxFlat = GameTheme.box(Color("182f35"), 12, GameTheme.BORDER)
var order_style: StyleBoxFlat = GameTheme.box(GameTheme.RAISED, 4, GameTheme.BORDER)
var order_active_style: StyleBoxFlat = GameTheme.box(GameTheme.RAISED, 4, GameTheme.GOLD)
var run: RunController
var combat: CombatController
var projection: BoardProjection
var effects: Array[Dictionary] = []
var time: float = 0.0
var wave_key: int = -1

func bind(controller: RunController, board_projection: BoardProjection) -> void:
	if combat == controller.combat: return
	if combat != null and combat.skill_used.is_connected(on_skill): combat.skill_used.disconnect(on_skill)
	run = controller
	combat = controller.combat
	projection = board_projection
	effects.clear()
	time = 0.0
	wave_key = run.state.global_wave()
	combat.skill_used.connect(on_skill)

func advance(_delta: float) -> void:
	var game_time: float = combat.abilities.clock
	if run.state.global_wave() != wave_key or run.state.phase != "battle" or game_time < time:
		effects.clear()
		wave_key = run.state.global_wave()
	time = game_time
	for effect: Dictionary in effects.duplicate():
		effect.age = maxf(0.0, game_time - float(effect.started_at))
		if effect.age >= 0.65: effects.erase(effect)

func on_skill(id: String, source: Dictionary, targets: Array) -> void:
	if id not in IMPACTS: return
	var points: Array[Vector2] = []
	for target: Dictionary in targets:
		points.append(point(target))
	effects.append({"id": id, "source_uid": source.uid, "origin": point(source), "targets": points, "age": 0.0, "started_at": combat.abilities.clock, "self_shield": id == "shield" and source.get("ability_state", "") in ["dough", "red_shield"]})
	if effects.size() > 48: effects.pop_front()

func point(unit: Dictionary) -> Vector2:
	return projection.foot(float(unit.get("x", float(unit.get("col", 0)) * 96.0 + 48.0)), int(unit.row))

func by_uid(uid: int) -> Dictionary:
	for unit: Dictionary in combat.enemies:
		if unit.uid == uid: return unit
	for unit: Dictionary in run.state.units:
		if unit.uid == uid: return unit
	return {}

func draw_ground(canvas: Node2D) -> void:
	if run.state.phase != "battle": return
	for effect: Dictionary in combat.abilities.ground_effects:
		var kind: String = str(effect.get("kind", effect.get("skill_id", "acid")))
		var tint: Color = TINTS.get(kind, TINTS.proof)
		var cells: Array = effect.get("cells", [])
		if cells.is_empty() and effect.has("col"): cells = [{"row": effect.row, "col": effect.col}]
		for cell: Dictionary in cells:
			draw_cell(canvas, cell, tint, false, float(effect.get("remaining", 0.0)), kind)
	for warning: Dictionary in combat.abilities.telegraphs:
		var kind: String = str(warning.get("kind", warning.get("skill_id", "")))
		var tint: Color = TINTS.get(kind, GameTheme.GOLD)
		var source: Dictionary = by_uid(int(warning.get("source_uid", -1)))
		if source.is_empty(): continue
		var origin: Vector2 = point(source)
		var remaining: float = float(warning.get("remaining", 0.0))
		var cells: Array = warning.get("cells", [])
		for cell: Dictionary in cells: draw_cell(canvas, cell, tint, true, remaining, kind)
		if kind == "dash":
			var end: Vector2 = projection.foot(clampf(float(warning.get("end_x", source.x - 72.0)), 0, RunState.BOARD_WIDTH), source.row)
			for offset: float in [-8.0, 8.0]: arrow(canvas, origin + Vector2(0, offset), end + Vector2(0, offset), tint)
		elif kind == "switch":
			var rows: Array = warning.get("rows", [])
			if rows.size() > 1:
				var destination: Vector2 = projection.foot(clampf(source.x, 0, RunState.BOARD_WIDTH), int(rows[-1]))
				arrow(canvas, origin, destination, tint)
				StatusFeedback.ring(canvas, destination, Vector2(24, 11), tint, 2)
		elif kind == "ration":
			var target: Dictionary = by_uid(int(warning.get("target_uid", -1)))
			if not target.is_empty(): arrow(canvas, origin - Vector2(0, 10), point(target) - Vector2(0, 10), tint)
		elif kind == "order":
			for row: int in warning.get("rows", []):
				draw_cell(canvas, {"row": row, "col": RunState.COLS - 1}, tint, true, remaining, kind)
		if cells.is_empty() and kind not in ["order", "dash", "switch"]:
			StatusFeedback.ring(canvas, origin, Vector2(29, 12), Color(tint, 0.8), 2)

func draw_cell(canvas: Node2D, cell: Dictionary, tint: Color, warning: bool, remaining: float, kind: String) -> void:
	var row: int = int(cell.get("row", -1))
	var col: int = int(cell.get("col", -1))
	if row < 0 or row >= RunState.ROWS or col < 0 or col >= RunState.COLS: return
	var polygon: PackedVector2Array = projection.tiles[row * RunState.COLS + col]
	canvas.draw_colored_polygon(polygon, Color(tint, (0.10 + 0.07 * sin(time * 5.0)) if warning else 0.22))
	for i: int in range(4):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % 4]
		if warning:
			for segment: int in range(4): canvas.draw_line(a.lerp(b, segment / 4.0), a.lerp(b, (segment + 0.55) / 4.0), tint, 2, true)
		else: canvas.draw_line(a, b, Color(tint, 0.95), 3, true)
	var center: Vector2 = (polygon[0] + polygon[2]) * 0.5
	if kind == "acid":
		center = polygon[0] + Vector2(14, 36)
		var drop := PackedVector2Array([center + Vector2(0, -14), center + Vector2(9, 1), center + Vector2(6, 8), center + Vector2(-6, 8), center + Vector2(-9, 1)])
		canvas.draw_colored_polygon(drop, Color(tint, 0.85))
		canvas.draw_polyline(PackedVector2Array([drop[0], drop[1], drop[2], drop[3], drop[4], drop[0]]), Color("536239"), 1.5, true)
	elif kind == "proof":
		center = polygon[0] + Vector2(17, 35)
		for shift: Vector2 in [Vector2(-7, 2), Vector2(0, -5), Vector2(7, 2)]: canvas.draw_arc(center + shift, 6, 0, TAU, 16, Color(tint, 0.95), 2, true)
	elif kind == "heavy":
		arrow(canvas, center + Vector2(0, -18), center + Vector2(0, 12), tint)
	text(canvas, polygon[0] + Vector2(5, 14), "%s %.1fs" % [LABELS.get(kind, "技能"), maxf(remaining, 0.0)], tint, 11)

static func arrow(canvas: Node2D, start: Vector2, end: Vector2, tint: Color) -> void:
	if start.distance_squared_to(end) < 4.0: return
	canvas.draw_line(start, end, Color(tint, 0.8), 2, true)
	var direction: Vector2 = (start - end).normalized()
	canvas.draw_polyline(PackedVector2Array([end + direction.rotated(0.55) * 10, end, end + direction.rotated(-0.55) * 10]), tint, 2, true)

func draw_unit(canvas: Node2D, enemy: Dictionary, foot: Vector2, height: float) -> void:
	if enemy.has("death_age"): return
	if enemy.id in ["rivet_guard", "rivet_foreman"] and enemy.armor > 0:
		for index: int in range(6):
			var p: Vector2 = foot + Vector2(-14 + index * 5 + (index / 2) * 2, -height * 0.64)
			canvas.draw_line(p, p + Vector2(0, 5), Color("eab675") if index < enemy.armor else Color("48565d"), 2, true)
	if float(enemy.get("shield", 0.0)) > 0:
		var shield_max: float = maxf(1.0, float(enemy.get("shield_max", enemy.shield)))
		canvas.draw_rect(Rect2(foot + Vector2(-23, 10), Vector2(46, 3)), Color("193a41"))
		canvas.draw_rect(Rect2(foot + Vector2(-23, 10), Vector2(46 * clampf(enemy.shield / shield_max, 0, 1), 3)), Color("8cdbef"))
		StatusFeedback.ring(canvas, foot - Vector2(0, height * 0.38), Vector2(height * 0.40, height * 0.48), Color(0.55, 0.86, 0.94, 0.3), 1.5)
	var phase: String = str(enemy.get("ability_phase", "normal"))
	if phase == "windup" and enemy.get("rank", "normal") != "boss":
		var p: Vector2 = foot - Vector2(0, height * 0.76 + 8)
		p.y = maxf(p.y, BoardProjection.ORIGIN.y + (29.0 if enemy.get("rank", "normal") == "elite" else 14.0))
		text(canvas, p - Vector2(34, 0), "%s %.1fs" % [enemy.get("ability_title", "蓄力"), enemy.get("ability_remaining", 0.0)], GameTheme.GOLD, 11)
	if float(enemy.get("exposed_time", 0.0)) > 0:
		StatusFeedback.ring(canvas, foot, Vector2(32, 12), GameTheme.ACCENT, 2.5)
		text(canvas, foot + Vector2(-20, 24), "破绽", GameTheme.ACCENT, 12)
	if enemy.get("rank", "normal") == "boss" and enemy.id == "boss_quartermaster":
		var remaining: int = int(enemy.get("order_remaining", 3))
		for index: int in range(3):
			var p: Vector2 = foot + Vector2((index - 1) * 12, -height * 0.62)
			canvas.draw_circle(p, 4.0, GameTheme.GOLD if index < remaining else Color("414d50"))

func cast_pose(enemy: Dictionary, pose: Dictionary) -> Dictionary:
	if enemy.has("death_age") or str(enemy.get("ability_phase", "normal")) == "normal": return pose
	var phase: String = str(enemy.get("ability_phase", "normal"))
	if phase == "windup":
		pose.scale *= Vector2(1.025, 0.97)
		pose.angle -= 0.025
	elif phase == "recovery":
		pose.scale *= Vector2(1.035, 0.94)
		pose.offset.y += 2.0
	return pose

func skill_frame(enemy: Dictionary) -> Vector2i:
	if enemy.has("death_age"): return Vector2i(-1, -1)
	var phase: String = str(enemy.get("ability_phase", "normal"))
	var duration: float = maxf(0.001, float(enemy.get("ability_duration", 0.0)))
	var progress: float = clampf(1.0 - float(enemy.get("ability_remaining", 0.0)) / duration, 0.0, 1.0)
	if phase == "windup": return Vector2i(mini(5, int(progress * 6.0)), 0)
	if phase == "action": return Vector2i(mini(5, int(progress * 6.0)), 1)
	# Instant hits enter recovery in the same combat step. Show the confirmed impact first.
	for index: int in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		if effect.source_uid != enemy.uid or effect.id not in ["dash", "switch", "heavy", "acid", "proof", "ration", "order", "shield", "skewer"]: continue
		if effect.id == "shield" and not effect.get("self_shield", false): continue
		if effect.age < 0.24: return Vector2i(mini(5, int(effect.age / 0.24 * 6.0)), 1)
		if phase == "normal": return Vector2i(mini(5, int((effect.age - 0.24) / 0.41 * 6.0)), 2)
	if phase == "recovery": return Vector2i(mini(5, int(progress * 6.0)), 2)
	return Vector2i(-1, -1)

func draw_effects(canvas: Node2D) -> void:
	for effect: Dictionary in effects:
		var progress: float = effect.age / 0.65
		var tint: Color = TINTS.get(effect.id, GameTheme.GOLD)
		var origin: Vector2 = effect.origin
		if effect.id == "skewer":
			var start: Vector2 = effect.targets[0] if not effect.targets.is_empty() else origin
			for target: Vector2 in effect.targets:
				canvas.draw_line(start - Vector2(0, 24), target - Vector2(0, 24), Color(tint, 1.0 - progress), 3, true)
		elif effect.id in ["heavy", "armor_break", "order_failed"]:
			StatusFeedback.ring(canvas, origin, Vector2(18 + 32 * progress, 8 + 14 * progress), Color(tint, 1.0 - progress), 3)
		else:
			for target: Vector2 in effect.targets:
				StatusFeedback.ring(canvas, target, Vector2(12 + 20 * progress, 5 + 10 * progress), Color(tint, 1.0 - progress), 2)

func active_boss() -> Dictionary:
	for enemy: Dictionary in combat.enemies:
		if enemy.get("rank", "normal") == "boss": return enemy
	return {}

func draw_boss_panel(canvas: Node2D) -> void:
	if run.state.phase != "battle": return
	var boss: Dictionary = active_boss()
	if boss.is_empty() or boss.id == "boss": return
	canvas.draw_style_box(boss_panel_style, BOSS_RECT)
	var origin: Vector2 = BOSS_RECT.position + Vector2(14, 24)
	var title: String = combat.enemy_title(boss.id)
	text(canvas, origin, title, GameTheme.GOLD, 16)
	text(canvas, origin + Vector2(0, 26), "生命 %.0f / %.0f" % [boss.hp, boss.max_hp], GameTheme.TEXT, 13)
	var bar := Rect2(origin + Vector2(0, 36), Vector2(202, 6))
	canvas.draw_rect(bar, GameTheme.RAISED)
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(boss.hp / boss.max_hp, 0, 1), 6)), GameTheme.DANGER)
	var shield: float = float(boss.get("shield", 0.0))
	text(canvas, origin + Vector2(0, 64), "护盾 %.0f" % shield if shield > 0 else "中央第 4 行 · 漏粮 10", Color("96d5df"), 12)
	var ability: String = str(boss.get("ability_title", ""))
	var remaining: float = float(boss.get("ability_remaining", 0.0))
	text(canvas, origin + Vector2(0, 89), (ability if not ability.is_empty() else "推进中") + ("  %.1fs" % remaining if remaining > 0 else ""), GameTheme.TEXT, 14)
	if boss.id == "boss_quartermaster":
		var names: Array[String] = ["急件", "铁箱", "面种"]
		var index: int = int(boss.get("order_index", -1))
		for i: int in range(3):
			var p: Vector2 = origin + Vector2(i * 68, 107)
			canvas.draw_style_box(order_active_style if i == index else order_style, Rect2(p, Vector2(61, 27)))
			text(canvas, p + Vector2(6, 18), names[i], GameTheme.GOLD if i == index else GameTheme.MUTED, 12)
		text(canvas, origin + Vector2(0, 156), "余 %d 单 · %s" % [int(boss.get("order_remaining", 3)), {"idle": "等待粮签", "warning": "第 3 / 5 行来援", "active": "护送 %.1fs" % boss.get("order_time", 0.0), "success": "签收口粮", "failed": "断单露出破绽", "done": "订单已结束"}.get(boss.get("order_status", "idle"), "")], GameTheme.ACCENT, 12)
	else:
		var hints: Dictionary = {"boss_windwhistle": ["吐司接冲刺", "喘气时集中输出"], "boss_ironpot": ["锅壳只出现一次", "破壳会打断重砸"], "boss_starter": ["留意醒面格", "回缩时集中输出"]}
		var lines: Array = hints.get(boss.id, [])
		for i: int in range(lines.size()): text(canvas, origin + Vector2(0, 119 + i * 23), lines[i], GameTheme.MUTED, 13)
	text(canvas, origin + Vector2(0, 195), "悬停首领查看技能与故事", GameTheme.MUTED, 11)

static func text(canvas: Node2D, pos: Vector2, value: String, tint: Color, size: int) -> void:
	canvas.draw_string_outline(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color("172b31"))
	canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint)
