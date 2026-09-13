class_name HeatPickupView
extends Node2D

const FLAME: Texture2D = preload("res://assets/ui/flame.svg")
const POP_DURATION: float = 0.35
const HIT_SIZE: Vector2 = Vector2(52, 58)
var run: RunController
var projection: BoardProjection
var target: Control

func resting_position(pickup: Dictionary) -> Vector2:
	var center: Vector2 = projection.project(Vector2(pickup.col * 96 + 48, pickup.row * 96 + 48))
	var pop: float = clampf(pickup.age / POP_DURATION, 0.0, 1.0)
	return center + Vector2(0, -20.0 * (1.0 - pow(1.0 - pop, 3.0)) + sin(pickup.age * 3.5) * 2.0 * pop)

func pickup_position(pickup: Dictionary) -> Vector2:
	var origin: Vector2 = resting_position(pickup)
	if pickup.flight < 0.0: return origin
	var t: float = clampf(pickup.flight / run.data.rules.heat_flight_duration, 0.0, 1.0)
	var end: Vector2 = target.get_global_rect().get_center()
	return origin.lerp(end, t * t) + Vector2(0, -sin(t * PI) * 45.0)

func pickup_at(point: Vector2) -> int:
	if run.state.phase != "battle": return -1
	for index: int in range(run.combat.heat_pickups.size() - 1, -1, -1):
		var pickup: Dictionary = run.combat.heat_pickups[index]
		# Consume clicks on a flying flame too, so double clicks cannot reach the board.
		if Rect2(pickup_position(pickup) - HIT_SIZE * 0.5, HIT_SIZE).has_point(point): return pickup.uid
	return -1

func _draw() -> void:
	if run.state == null or run.state.phase != "battle": return
	for pickup: Dictionary in run.combat.heat_pickups:
		var pos: Vector2 = pickup_position(pickup)
		var flying: bool = pickup.flight >= 0.0
		var progress: float = clampf(pickup.flight / run.data.rules.heat_flight_duration, 0.0, 1.0)
		var scale_value: float = lerpf(1.0, 0.45, progress) if flying else lerpf(0.6, 1.0, clampf(pickup.age / POP_DURATION, 0.0, 1.0))
		var hovered: bool = not flying and pickup_at(get_global_mouse_position()) == pickup.uid
		draw_circle(pos, (25.0 if hovered else 22.0) * scale_value, Color(1.0, 0.62, 0.15, 0.2))
		draw_circle(pos, 17.0 * scale_value, Color(1.0, 0.77, 0.28, 0.16))
		var size_value: Vector2 = Vector2(32, 38) * scale_value
		draw_texture_rect(FLAME, Rect2(pos - size_value * 0.5, size_value), false)
		if not flying:
			var caption: String = "+%.0f" % pickup.amount
			var font: Font = ThemeDB.fallback_font
			var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var baseline: Vector2 = pos + Vector2(-width * 0.5, 32)
			draw_string_outline(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("18221c"))
			draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GameTheme.GOLD)
