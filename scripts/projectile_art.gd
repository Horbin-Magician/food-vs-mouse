class_name ProjectileArt
extends RefCounted

const TEXTURES: Dictionary = {
	"bun": preload("res://assets/art/projectiles/bun.svg"),
	"bun_pressure": preload("res://assets/art/projectiles/bun_pressure.svg"),
	"tea": preload("res://assets/art/projectiles/tea.svg"),
	"pepper": preload("res://assets/art/projectiles/pepper.svg"),
	"popcorn": preload("res://assets/art/projectiles/popcorn.svg"),
	"noodles": preload("res://assets/art/projectiles/noodles.svg"),
}
const SIZES: Dictionary = {
	"bun": Vector2(38, 28), "bun_pressure": Vector2(46, 34),
	"tea": Vector2(36, 28), "pepper": Vector2(42, 28),
	"popcorn": Vector2(34, 30), "noodles": Vector2(46, 24),
}

static func draw_shot(canvas: CanvasItem, shot: Dictionary, position: Vector2, scale_value: float) -> void:
	var key: String = shot.get("source", "")
	if key == "bun" and shot.get("radius", 0.0) > 0.0:
		key = "bun_pressure"
	if not TEXTURES.has(key):
		canvas.draw_circle(position, 5 * scale_value, Color("fff1b5"))
		return
	var size: Vector2 = SIZES[key] * scale_value
	canvas.draw_texture_rect(TEXTURES[key], Rect2(position - size * 0.5, size), false)
