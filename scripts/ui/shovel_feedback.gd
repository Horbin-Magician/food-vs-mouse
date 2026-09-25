class_name ShovelFeedback
extends RefCounted

const DURATION: float = 0.42
const SPATULA: Texture2D = preload("res://assets/ui/spatula.svg")
var effects: Array[Dictionary] = []
var board: BoardController
var state: RunState
var projection: BoardProjection
var art: ArtCatalog
var phase: String

func bind(run: RunController, board_projection: BoardProjection, catalog: ArtCatalog) -> void:
	if state == run.state:
		if phase != state.phase:
			effects.clear()
			phase = state.phase
		return
	if board != null and board.removed.is_connected(on_removed): board.removed.disconnect(on_removed)
	effects.clear()
	state = run.state
	board = run.board
	projection = board_projection
	art = catalog
	phase = state.phase
	board.removed.connect(on_removed)

func on_removed(unit: Dictionary) -> void:
	effects.append({"age": 0.0, "foot": projection.foot(unit.col * 96 + 48, unit.row), "depth": projection.depth_scale(unit.row), "texture": art.food(unit.id)})

func advance(delta: float) -> void:
	if state == null: return
	if phase != state.phase:
		effects.clear()
		phase = state.phase
	for effect: Dictionary in effects.duplicate():
		effect.age += delta
		if effect.age >= DURATION: effects.erase(effect)

func draw(canvas: Node2D) -> void:
	for effect: Dictionary in effects:
		var t: float = clampf(effect.age / DURATION, 0.0, 1.0)
		var lift: float = smoothstep(0.18, 1.0, t)
		var alpha: float = 1.0 - smoothstep(0.45, 1.0, t)
		var depth: float = effect.depth
		var foot: Vector2 = effect.foot
		var size: Vector2 = Vector2(66, 76) * depth * (1.0 - 0.65 * lift)
		var center: Vector2 = foot + Vector2(12 * lift, -28 - 42 * lift) * depth
		canvas.draw_set_transform(center, -0.35 * lift)
		canvas.draw_texture_rect(effect.texture, Rect2(-size * 0.5, size), false, Color(1, 1, 1, alpha))
		canvas.draw_set_transform(foot + Vector2(10 - 24 * lift, -5 - 36 * lift) * depth, lerpf(-0.8, 0.6, smoothstep(0, 0.8, t)))
		canvas.draw_texture_rect(SPATULA, Rect2(-22 * depth, -42 * depth, 44 * depth, 44 * depth), false, Color(1, 1, 1, alpha))
		canvas.draw_set_transform(Vector2.ZERO)
		if t > 0.12:
			canvas.draw_arc(foot - Vector2(0, 18) * depth, (20 + 18 * lift) * depth, -2.9, -0.4, 18, Color(1.0, 0.88, 0.55, alpha * 0.7), 2.0, true)
