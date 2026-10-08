extends RefCounted
## Fonts, labels and buttons shared by every screen.

const INTER := preload("res://assets/fonts/Inter.ttf")
const GOLD := Color("#ffd447")
const TEXT := Color("#f4f1ff")
const SUB := Color("#a9a3d9")

static var _fonts := {}


## Inter at a weight from 100 (thin) to 900 (black).
static func font(weight := 500) -> Font:
	if not _fonts.has(weight):
		var v := FontVariation.new()
		v.base_font = INTER
		var ts := TextServerManager.get_primary_interface()
		v.variation_opentype = {ts.name_to_tag("wght"): weight}
		_fonts[weight] = v
	return _fonts[weight]


static func label(text: String, size_px: int, color := TEXT, weight := 600) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A soft coloured halo around the letters.
static func glow(l: Label, color: Color, radius := 16) -> void:
	l.add_theme_color_override("font_shadow_color", color)
	l.add_theme_constant_override("shadow_outline_size", radius)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)


static func _pill(color: Color, glow_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(80)
	sb.shadow_color = glow_color
	sb.shadow_size = 28
	sb.anti_aliasing = true
	return sb


## A big rounded glowing button.
static func pill_button(text: String, color: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(620, 150)
	b.add_theme_font_override("font", font(800))
	b.add_theme_font_size_override("font_size", 58)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("#1a1040"))
	var glow_color := Color(color, 0.55)
	b.add_theme_stylebox_override("normal", _pill(color, glow_color))
	b.add_theme_stylebox_override("hover", _pill(color, glow_color))
	b.add_theme_stylebox_override("focus", _pill(color, glow_color))
	b.add_theme_stylebox_override("pressed", _pill(color.darkened(0.15), Color(color, 0.3)))
	b.pressed.connect(func() -> void:
		Sfx.play("click")
		on_press.call())
	return b


## 12 480 rather than 12480.
static func number(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
