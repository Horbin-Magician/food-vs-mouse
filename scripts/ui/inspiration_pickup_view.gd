class_name InspirationPickupView
extends Node2D

const LIGHT := Color("e3c2ff")
const VIOLET := Color("aa71e6")
const POP_DURATION: float = 0.35
const HIT_SIZE: Vector2 = Vector2(52, 58)
var run: RunController
var projection: BoardProjection
var target: Control

func resting_position(pickup: Dictionary) -> Vector2:
	var center: Vector2 = projection.project(Vector2(pickup.x, pickup.row * 96 + 48))
	var pop: float = clampf(pickup.age / POP_DURATION, 0.0, 1.0)
	return center + Vector2(0, -16.0 * (1.0 - pow(1.0 - pop, 3.0)) + sin(pickup.age * 3.5) * 2.0 * pop)

func pickup_position(pickup: Dictionary) -> Vector2:
	var origin: Vector2 = resting_position(pickup)
	if pickup.flight < 0.0: return origin
	var t: float = clampf(pickup.flight / run.data.progression.inspiration_flight_duration, 0.0, 1.0)
	return origin.lerp(target.get_global_rect().get_center(), t * t) + Vector2(0, -sin(t * PI) * 45.0)

func pickup_at(point: Vector2) -> int:
	if run.state == null or run.state.phase != "battle": return -1
	for index: int in range(run.combat.inspiration_pickups.size() - 1, -1, -1):
		var pickup: Dictionary = run.combat.inspiration_pickups[index]
		# Flying sparks still intercept repeated clicks above cards and the board.
		if Rect2(pickup_position(pickup) - HIT_SIZE * 0.5, HIT_SIZE).has_point(point): return pickup.uid
	return -1

func sparkle(pos: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -radius), pos + Vector2(radius * 0.28, -radius * 0.28),
		pos + Vector2(radius * 0.72, 0), pos + Vector2(radius * 0.28, radius * 0.28),
		pos + Vector2(0, radius), pos + Vector2(-radius * 0.28, radius * 0.28),
		pos + Vector2(-radius * 0.72, 0), pos + Vector2(-radius * 0.28, -radius * 0.28)
	]), color)

func _draw() -> void:
	if run.state == null or run.state.phase != "battle": return
	for pickup: Dictionary in run.combat.inspiration_pickups:
		var pos: Vector2 = pickup_position(pickup)
		var flying: bool = pickup.flight >= 0.0
		var progress: float = clampf(pickup.flight / run.data.progression.inspiration_flight_duration, 0.0, 1.0)
		var scale_value: float = lerpf(1.0, 0.45, progress) if flying else lerpf(0.6, 1.0, clampf(pickup.age / POP_DURATION, 0.0, 1.0))
		var hovered: bool = not flying and pickup_at(get_global_mouse_position()) == pickup.uid
		draw_circle(pos, (26.0 if hovered else 23.0) * scale_value, Color(VIOLET, 0.22))
		draw_circle(pos, 17.0 * scale_value, Color(VIOLET, 0.18))
		sparkle(pos, 20.0 * scale_value, VIOLET)
		sparkle(pos, 13.0 * scale_value, LIGHT)
		sparkle(pos + Vector2(15, -15) * scale_value, 5.0 * scale_value, LIGHT)
		sparkle(pos + Vector2(-15, 9) * scale_value, 3.0 * scale_value, LIGHT)
		if not flying:
			var caption: String = "+%d" % pickup.amount
			var font: Font = ThemeDB.fallback_font
			var width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var baseline: Vector2 = pos + Vector2(-width * 0.5, 32)
			draw_string_outline(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("281a36"))
			draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LIGHT)
