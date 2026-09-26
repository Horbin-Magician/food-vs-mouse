class_name BattleArt
extends RefCounted

# Static decoration is cached once; no controls or gameplay state live here.
const BACKGROUND = preload("res://assets/art/battle_kitchen.png")
var tile_light := GameTheme.box(Color("d5d4b6"), 5, Color("ece5c9"))
var tile_dark := GameTheme.box(Color("bdc9b0"), 5, Color("dce1c5"))
var wood := GameTheme.box(Color("5b4735"), 12, Color("be9860"))
var inset := GameTheme.box(Color("243e39"), 8, Color("8c9a79"))
var panel := GameTheme.box(Color("193331f2"), 12, Color("a28857"))
var dark := GameTheme.box(Color("112724"), 3)
var mint := GameTheme.box(Color("a4ddc0"), 3)

func background(canvas: Node2D) -> void:
	canvas.draw_texture_rect(BACKGROUND, Rect2(0, 0, 1280, 720), false)
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

func hud(canvas: Node2D, state: RunState, paused: bool) -> void:
	canvas.draw_style_box(panel, Rect2(12, -14, 1256, 98))
	canvas.draw_line(Vector2(28, 82), Vector2(1252, 82), Color("d5b477"), 2)
	canvas.draw_style_box(inset, Rect2(24, 8, 144, 64))
	canvas.draw_texture_rect(preload("res://assets/ui/flame.svg"), Rect2(36, 15, 26, 30), false)
	caption(canvas, Vector2(38, 62), "热量储备", 11, GameTheme.MUTED)
	canvas.draw_line(Vector2(178, 16), Vector2(178, 66), Color("a2885770"))
	canvas.draw_style_box(inset, Rect2(846, 12, 138, 58))
	caption(canvas, Vector2(860, 34), "粮仓耐久", 12, GameTheme.MUTED)
	caption(canvas, Vector2(860, 58), "%02d / 10" % state.pantry, 21, GameTheme.GOLD if state.pantry > 3 else GameTheme.DANGER)
	canvas.draw_style_box(inset, Rect2(994, 12, 100, 58))
	caption(canvas, Vector2(1008, 34), "金币", 12, GameTheme.MUTED)
	caption(canvas, Vector2(1008, 58), "%02d" % state.coins, 21, GameTheme.GOLD)
	canvas.draw_circle(Vector2(1200, 36), 28, Color("294840"))
	canvas.draw_arc(Vector2(1200, 36), 28, 0, TAU, 48, Color("a28857"), 1, true)
	canvas.draw_style_box(panel, Rect2(12, 674, 1256, 60))
	caption(canvas, Vector2(250, 700), "深 夜 食 堂", 16, GameTheme.GOLD)
	caption(canvas, Vector2(398, 699), "打烊之后，守住这一餐。", 12, GameTheme.MUTED)
	canvas.draw_style_box(panel, Rect2(40, 112, 184, 80))
	caption(canvas, Vector2(59, 139), "今夜 · 守护粮仓", 16, GameTheme.GOLD)
	for index: int in range(10):
		canvas.draw_style_box(mint if index < state.pantry else dark, Rect2(59 + index * 14, 155, 10, 8))
	caption(canvas, Vector2(59, 180), "食物的最后一道防线", 11, GameTheme.MUTED)
	canvas.draw_style_box(panel, Rect2(1100, 112, 144, 80))
	caption(canvas, Vector2(1115, 140), "第 %02d 夜" % state.wave, 22, GameTheme.GOLD)
	caption(canvas, Vector2(1115, 170), "休息片刻" if paused else "鼠潮来袭", 12, GameTheme.MUTED)
