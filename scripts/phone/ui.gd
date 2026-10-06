extends RefCounted
## Shared building blocks for the phone apps: fonts, labels, rounded boxes.

const INTER := preload("res://assets/fonts/Inter.ttf")
const CAVEAT := preload("res://assets/fonts/Caveat.ttf")
const SERIF := preload("res://assets/fonts/PTSerif-Regular.ttf")
const SERIF_BOLD := preload("res://assets/fonts/PTSerif-Bold.ttf")
const TOUCH_SCROLL := preload("res://scripts/phone/touch_scroll.gd")

static var _cache := {}
## True while a finger is scrolling a page; buttons ignore the release then.
static var dragging := false


## Inter at a given weight (400 regular … 700 bold).
static func sans(weight := 400) -> Font:
	return _variation(INTER, weight)


## Handwriting, for Lev's notes and the parcel note.
static func hand(weight := 500) -> Font:
	return _variation(CAVEAT, weight)


static func serif(bold := false) -> Font:
	return SERIF_BOLD if bold else SERIF


static func _variation(base: FontFile, weight: int) -> Font:
	var key := "%s:%d" % [base.resource_path, weight]
	if not _cache.has(key):
		var v := FontVariation.new()
		v.base_font = base
		var ts := TextServerManager.get_primary_interface()
		v.variation_opentype = {ts.name_to_tag("wght"): weight}
		_cache[key] = v
	return _cache[key]


static func label(text: String, size_px: int, color: Color, font: Font = null, wrap_width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font if font else sans())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = wrap_width
	return l


static func box(color: Color, radius := 0, margin := 0.0, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	return sb


static func panel(color: Color, radius := 0, margin := 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## An invisible full-size button laid over `parent`, for tappable cards and rows.
static func tap_area(parent: Control, on_press: Callable, pressed_tint := Color(1, 1, 1, 0.06)) -> Button:
	var b := Button.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", box(pressed_tint, 16))
	b.pressed.connect(_guarded(on_press))
	parent.add_child(b)
	return b


## A press that ended a scroll gesture is not a tap.
static func _guarded(on_press: Callable) -> Callable:
	return func() -> void:
		if not dragging:
			on_press.call()


## Wraps `content` so the whole of it can be tapped (works inside boxes too).
static func tappable(content: Control, on_press: Callable, pressed_tint := Color(1, 1, 1, 0.06)) -> Control:
	var wrap := MarginContainer.new()
	wrap.add_child(content)
	tap_area(wrap, on_press, pressed_tint)
	return wrap


static func text_button(text: String, size_px: int, color: Color, on_press: Callable, font: Font = null) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_font_override("font", font if font else sans(500))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, color)
	b.add_theme_color_override("font_pressed_color", color.darkened(0.3))
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.pressed.connect(_guarded(on_press))
	return b


## A vertical scroller filling `parent` between the given top and bottom insets.
static func scroller(parent: Control, top: float, bottom := 0.0, side := 0.0) -> VBoxContainer:
	var scroll: ScrollContainer = TOUCH_SCROLL.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = top
	scroll.offset_bottom = -bottom
	scroll.offset_left = side
	scroll.offset_right = -side
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	parent.set_meta("scroll", scroll)
	return list


static func spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## A picture that keeps its proportions inside a fixed width.
static func picture(tex: Texture2D, width: float, max_height := 0.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var h := width * tex.get_height() / tex.get_width()
	if max_height > 0.0:
		h = minf(h, max_height)
	t.custom_minimum_size = Vector2(width, h)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A picture cropped to fill a box, like thumbnails and article heroes.
static func cover(tex: Texture2D, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = size
	t.clip_contents = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
