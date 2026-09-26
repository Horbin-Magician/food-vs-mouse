class_name GameTheme
extends RefCounted

# Presentation tokens only; gameplay values remain in definition resources.
const BG := Color("101e1d")
const SURFACE := Color("1a302d")
const RAISED := Color("263e37")
const BORDER := Color("496052")
const TEXT := Color("f7efd9")
const MUTED := Color("adbbb0")
const ACCENT := Color("a7d8b8")
const GOLD := Color("f0ca86")
const DANGER := Color("f4a293")

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
		theme.set_color("font_disabled_color", kind, Color("91a297"))
		theme.set_stylebox("normal", kind, box(RAISED, 10, BORDER))
		theme.set_stylebox("hover", kind, box(Color("365345"), 10, GOLD))
		theme.set_stylebox("pressed", kind, box(Color("365544"), 10, ACCENT))
		theme.set_stylebox("hover_pressed", kind, box(Color("40634e"), 10, GOLD))
		theme.set_stylebox("disabled", kind, box(Color("1b2b26"), 10, Color("35473d")))
		theme.set_stylebox("focus", kind, box(Color.TRANSPARENT, 10, GOLD))
	theme.set_constant("outline_size", "Button", 0)
	theme.set_stylebox("panel", "TooltipPanel", box(Color("102023"), 10, BORDER))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	for kind: String in ["VScrollBar", "HScrollBar"]:
		for state: String in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			var scroll_style := box({"scroll": BG, "grabber": BORDER, "grabber_highlight": ACCENT, "grabber_pressed": GOLD}[state], 4)
			scroll_style.content_margin_left = 5
			scroll_style.content_margin_right = 5
			scroll_style.content_margin_top = 5
			scroll_style.content_margin_bottom = 5
			theme.set_stylebox(state, kind, scroll_style)
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
	node.add_theme_stylebox_override("normal", box(GOLD, 10, Color("ffe3ad")))
	node.add_theme_stylebox_override("hover", box(Color("ffe1a7"), 10, Color("fff0ce")))
	node.add_theme_stylebox_override("pressed", box(Color("d9ad68"), 10))
	node.add_theme_stylebox_override("hover_pressed", box(Color("e1b978"), 10))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, BG)

static func food_card(node: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var frame := StyleBoxTexture.new()
		frame.texture = preload("res://assets/ui/food_card.svg")
		frame.modulate_color = Color("fff0bc") if state in ["pressed", "hover_pressed"] else (Color("c8fff0") if state == "hover" else Color.WHITE)
		node.add_theme_stylebox_override(state, frame)
	var focus := box(Color.TRANSPARENT, 6, GOLD)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus", focus)
