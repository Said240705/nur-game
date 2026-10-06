extends CanvasLayer
## Film language for the director: fades to black, letterbox bars,
## captions that wait for a tap, and the title card.

const TEXT := Color(0.93, 0.94, 0.96)
const BAR := 140.0
const ROTATE_HINT := "Поверни телефон горизонтально"

var _fade: ColorRect
var _top: ColorRect
var _bottom: ColorRect
var _header: Label
var _caption: Label
var _footer: Label
var _title: Label
var _subtitle: Label
var _tapped := false
var _rotate: Label
var _hint: Label
var _blink := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS

	_top = _bar(Control.PRESET_TOP_WIDE)
	_bottom = _bar(Control.PRESET_BOTTOM_WIDE)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_title = _label(150, 0.0)
	_subtitle = _label(34, 150.0)
	_subtitle.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6))
	_header = _label(26, -190.0)
	_header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.66))
	_caption = _label(44, 0.0)
	_footer = _label(26, 0.0)
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_footer.offset_bottom = -170.0
	_footer.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))

	_hint = _label(30, 0.0)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_hint.offset_top = 70.0
	_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.78))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_y", 2)

	_rotate = _label(72, 0.0)
	_rotate.offset_left = 40.0
	_rotate.offset_right = -40.0
	_rotate.text = ROTATE_HINT
	var back := ColorRect.new()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.color = Color.BLACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.show_behind_parent = true
	_rotate.add_child(back)


func _bar(preset: Control.LayoutPreset) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(preset)
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	if preset == Control.PRESET_TOP_WIDE:
		r.offset_bottom = 0.0
	else:
		r.offset_top = 0.0
	return r


func _label(font_size: int, shift_y: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 160.0
	l.offset_right = -160.0
	l.offset_top = shift_y
	l.offset_bottom = shift_y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", TEXT)
	l.add_theme_constant_override("line_spacing", 10)
	l.modulate.a = 0.0
	add_child(l)
	return l


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		_tapped = true


func _process(delta: float) -> void:
	var view := get_viewport().get_visible_rect().size
	_rotate.modulate.a = 1.0 if view.y > view.x else 0.0
	if _footer.modulate.a > 0.0 and _footer.has_meta("blink"):
		_blink += delta
		_footer.modulate.a = 0.45 + 0.4 * sin(_blink * 2.5)


func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_SINE)


func set_black(alpha: float) -> void:
	_fade.color = Color(0, 0, 0, alpha)


func fade_to(alpha: float, duration: float) -> void:
	var tw := _tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


func letterbox(on: bool, duration := 0.9) -> void:
	var tw := _tween().set_parallel()
	tw.tween_property(_top, "offset_bottom", BAR if on else 0.0, duration)
	tw.tween_property(_bottom, "offset_top", -BAR if on else 0.0, duration)
	await tw.finished


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


## Wait for the given time, or less if the player taps.
func hold(seconds: float) -> void:
	_tapped = false
	var t := 0.0
	while t < seconds and not _tapped:
		await get_tree().process_frame
		t += get_process_delta_time()


func wait_tap() -> void:
	_tapped = false
	while not _tapped:
		await get_tree().process_frame


func show_label(l: Label, text: String, duration := 0.9) -> void:
	l.text = text
	var tw := _tween()
	tw.tween_property(l, "modulate:a", 1.0, duration)
	await tw.finished


func hide_label(l: Label, duration := 0.7) -> void:
	var tw := _tween()
	tw.tween_property(l, "modulate:a", 0.0, duration)
	await tw.finished


## Fade a line in, hold it, fade it out.
func caption(text: String, seconds: float, font_size := 44) -> void:
	_caption.add_theme_font_size_override("font_size", font_size)
	await show_label(_caption, text)
	await hold(seconds)
	await hide_label(_caption)


## A text card that stays until tapped (with a blinking prompt).
func card(header: String, body: String, prompt: String) -> void:
	_caption.add_theme_font_size_override("font_size", 40)
	if header != "":
		show_label(_header, header)
	await show_label(_caption, body, 1.2)
	await wait(1.2)
	await prompt_and_wait(prompt)
	if header != "":
		hide_label(_header)
	await hide_label(_caption)


func prompt_and_wait(prompt: String) -> void:
	_footer.text = prompt
	_footer.set_meta("blink", true)
	_blink = 0.0
	_footer.modulate.a = 0.45
	await wait_tap()
	_footer.remove_meta("blink")
	hide_label(_footer, 0.3)


func show_title(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_title.offset_top = -70.0
	_title.offset_bottom = -70.0
	var tw := _tween().set_parallel()
	tw.tween_property(_title, "modulate:a", 1.0, 2.2)
	tw.tween_property(_subtitle, "modulate:a", 1.0, 2.2).set_delay(1.2)
	await tw.finished


func hide_title(duration := 1.0) -> void:
	var tw := _tween().set_parallel()
	tw.tween_property(_title, "modulate:a", 0.0, duration)
	tw.tween_property(_subtitle, "modulate:a", 0.0, duration)
	await tw.finished


## A small hint near the top that fades out by itself.
func hint(text: String, seconds := 4.0) -> void:
	await show_label(_hint, text, 0.8)
	await wait(seconds)
	await hide_label(_hint, 1.0)
