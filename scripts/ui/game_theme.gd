class_name GameTheme
extends RefCounted

# Presentation tokens only; gameplay values remain in definition resources.
const BG := Color("111f21")
const SURFACE := Color("1b2e30")
const RAISED := Color("253c3d")
const BORDER := Color("375052")
const TEXT := Color("f2efdf")
const MUTED := Color("a5b9b5")
const ACCENT := Color("a4ddc0")
const GOLD := Color("efc884")
const DANGER := Color("f29b8f")

static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	for kind: String in ["Button", "LineEdit", "SpinBox"]:
		theme.set_color("font_color", kind, TEXT)
		theme.set_color("font_hover_color", kind, TEXT)
		theme.set_color("font_pressed_color", kind, ACCENT)
		theme.set_color("font_focus_color", kind, TEXT)
		theme.set_color("font_disabled_color", kind, Color("788d88"))
		theme.set_stylebox("normal", kind, box(RAISED, 10, BORDER))
		theme.set_stylebox("hover", kind, box(Color("324c49"), 10, ACCENT))
		theme.set_stylebox("pressed", kind, box(Color("36594e"), 10, ACCENT))
		theme.set_stylebox("disabled", kind, box(Color("1c2d2f"), 10, Color("293e40")))
		theme.set_stylebox("focus", kind, box(Color.TRANSPARENT, 10, GOLD))
	theme.set_constant("outline_size", "Button", 0)
	theme.set_stylebox("panel", "TooltipPanel", box(Color("102023"), 10, BORDER))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	theme.set_stylebox("panel", "AcceptDialog", box(SURFACE, 16, BORDER))
	theme.set_constant("margin", "AcceptDialog", 24)
	theme.set_constant("buttons_separation", "AcceptDialog", 12)
	var window_border := box(SURFACE, 16, BORDER)
	window_border.expand_margin_top = 36
	theme.set_stylebox("embedded_border", "Window", window_border)
	theme.set_constant("title_height", "Window", 36)
	theme.set_color("title_color", "Window", TEXT)
	theme.set_font_size("title_font_size", "Window", 18)
	return theme

static func primary(node: Button) -> void:
	node.add_theme_stylebox_override("normal", box(ACCENT, 10))
	node.add_theme_stylebox_override("hover", box(Color("beeacf"), 10))
	node.add_theme_stylebox_override("pressed", box(Color("84c7a5"), 10))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, BG)
