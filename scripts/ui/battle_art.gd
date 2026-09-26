class_name BattleArt
extends RefCounted

# Static decoration is cached once; no controls or gameplay state live here.
const BACKGROUND = preload("res://assets/art/battle_kitchen.png")
var tile_light := GameTheme.box(Color("d5d4b6"), 5, Color("ece5c9"))
var tile_dark := GameTheme.box(Color("bdc9b0"), 5, Color("dce1c5"))
var wood := GameTheme.box(Color("5b4735"), 12, Color("be9860"))
var inset := GameTheme.box(Color("243e39"), 8, Color("8c9a79"))
var panel := GameTheme.box(GameTheme.SURFACE, 12, GameTheme.BORDER)

func background(canvas: Node2D, tint: Color = Color(0, 0, 0, 0)) -> void:
	canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, 1280, 720), false)
	if tint.a > 0: canvas.draw_rect(Rect2(0, 0, 1280, 720), tint)
	canvas.draw_style_box(wood, Rect2(259, 80, 762, 592))
	canvas.draw_style_box(inset, Rect2(267, 84, 746, 582))
	for pos: Vector2 in [Vector2(263, 86), Vector2(1017, 86), Vector2(263, 666), Vector2(1017, 666)]:
		canvas.draw_circle(pos, 2, GameTheme.GOLD)

func tile(canvas: Node2D, bounds: Rect2, light: bool) -> void:
	canvas.draw_style_box(tile_light if light else tile_dark, bounds)
	canvas.draw_line(bounds.position + Vector2(7, 3), Vector2(bounds.end.x - 7, bounds.position.y + 3), Color("ffffff24"), 1)
	canvas.draw_line(Vector2(bounds.position.x + 7, bounds.end.y - 2), bounds.end - Vector2(7, 2), Color("5a796026"), 1)

func caption(canvas: Node2D, pos: Vector2, value: String, size: int, color: Color) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func hud(canvas: Node2D, state: RunState, _paused: bool) -> void:
	canvas.draw_style_box(panel, Rect2(12, -14, 1256, 98))
	canvas.draw_line(Vector2(28, 82), Vector2(1252, 82), Color("d5b47770"), 1)
	canvas.draw_style_box(inset, Rect2(24, 4, 144, 74))
	canvas.draw_texture_rect(preload("res://assets/ui/flame.svg"), Rect2(36, 10, 24, 28), false)
	canvas.draw_line(Vector2(178, 16), Vector2(178, 66), Color("a2885770"))
	canvas.draw_style_box(inset, Rect2(846, 12, 138, 58))
	caption(canvas, Vector2(860, 34), "粮仓", 12, GameTheme.MUTED)
	caption(canvas, Vector2(860, 58), "%02d / 10" % state.pantry, 21, GameTheme.GOLD if state.pantry > 3 else GameTheme.DANGER)
	canvas.draw_style_box(inset, Rect2(994, 12, 100, 58))
	caption(canvas, Vector2(1008, 34), "今夜灵感", 12, GameTheme.MUTED)
	canvas.draw_circle(Vector2(1232, 40), 24, Color("294840"))
	canvas.draw_arc(Vector2(1232, 40), 24, 0, TAU, 48, Color("a28857"), 1, true)
	canvas.draw_style_box(panel, Rect2(12, 674, 1256, 60))
	canvas.draw_line(Vector2(28, 675), Vector2(1252, 675), Color("d5b47740"), 1)
	caption(canvas, Vector2(34, 700), "深 夜 食 堂", 16, GameTheme.GOLD)
