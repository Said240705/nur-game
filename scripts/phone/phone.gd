extends Control
## A believable smartphone built from Controls: lock screen (tap or passcode),
## home screen, and the apps a detective digs through. Everything it shows comes
## from a data script (see scripts/story/*_phone.gd), so each phone is just data.
## The director listens to `viewed` to move the story along.

signal viewed(key: String)
signal unlocked

const BG := Color(0.035, 0.04, 0.055)
const CARD := Color(0.1, 0.11, 0.14)
const TEXT := Color(0.95, 0.95, 0.97)
const SUB := Color(0.6, 0.62, 0.68)
const STATUS_H := 110.0
const W := 1080.0

var data: Script
var is_locked := true

var _accent := Color.WHITE
var _status_time: Label
var _status_batt: Label
var _screen: Control
var _stack: Array[Control] = []
var _code_entry := ""
var _dots: HBoxContainer
var _keypad_box: Control
var _battery := 100
## Mutable copy of the chats, so read state can change during play.
var _chats: Array = []


func setup(phone_data: Script) -> void:
	data = phone_data
	_accent = data.ACCENT
	_battery = data.LOCK["battery"]
	_chats = data.CHATS.duplicate(true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var theme_ := Theme.new()
	theme_.default_font_size = 44
	theme = theme_

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	_build_status_bar()
	_show_lock()


func battery() -> int:
	return _battery


func set_battery(value: int) -> void:
	_battery = value
	_status_batt.text = "%d%%" % value


# --- Status bar -------------------------------------------------------------

func _build_status_bar() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = STATUS_H
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_status_time = _label(data.LOCK["time"], 40, TEXT)
	_status_time.position = Vector2(70, 40)
	bar.add_child(_status_time)
	_status_batt = _label("%d%%" % _battery, 38, TEXT)
	_status_batt.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_batt.offset_left = -200
	_status_batt.offset_right = -70
	_status_batt.offset_top = 40
	_status_batt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status_batt)


# --- Lock screen ------------------------------------------------------------

func _show_lock() -> void:
	_clear_screen()
	var lock := Control.new()
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(lock)
	_wallpaper(lock, 0.55)

	var time := _label(data.LOCK["time"], 200, TEXT)
	time.set_anchors_preset(Control.PRESET_TOP_WIDE)
	time.offset_top = 230
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(time)
	var date := _label(data.LOCK["date"], 46, Color(TEXT, 0.85))
	date.set_anchors_preset(Control.PRESET_TOP_WIDE)
	date.offset_top = 190
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(date)

	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_TOP_WIDE)
	list.offset_top = 560
	list.offset_left = 50
	list.offset_right = -50
	list.add_theme_constant_override("separation", 20)
	lock.add_child(list)
	for n in data.LOCK["notifications"]:
		list.add_child(_notice_card(n[0], n[1], n[2]))

	var hint := _label("Нажми, чтобы разблокировать" if data.CODE == "" else "Нажми, чтобы ввести код", 38, Color(TEXT, 0.7))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -330
	hint.offset_bottom = -270
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(hint)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.35, 1.2)
	tw.tween_property(hint, "modulate:a", 1.0, 1.2)

	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.focus_mode = Control.FOCUS_NONE
	_no_style(tap)
	tap.pressed.connect(_on_lock_tapped)
	lock.add_child(tap)


func _on_lock_tapped() -> void:
	if data.CODE == "":
		Sfx.play("unlock", -8.0)
		_unlock()
	else:
		_show_keypad()


func _show_keypad() -> void:
	_clear_screen()
	_code_entry = ""
	var pad := Control.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(pad)
	_wallpaper(pad, 0.8)
	_keypad_box = pad

	var title := _label("Введите код-пароль", 52, TEXT)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 330
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad.add_child(title)

	_dots = HBoxContainer.new()
	_dots.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_dots.offset_top = 440
	_dots.offset_left = -150
	_dots.offset_right = 150
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 44)
	pad.add_child(_dots)
	for i in data.CODE.length():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(34, 34)
		d.add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.0), 17, Color(1, 1, 1, 0.9), 3))
		_dots.add_child(d)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.set_anchors_preset(Control.PRESET_CENTER_TOP)
	grid.offset_top = 640
	grid.offset_left = -330
	grid.offset_right = 330
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 40)
	pad.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"]:
		if k == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(180, 180)
			grid.add_child(spacer)
			continue
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(180, 180)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 72 if k != "⌫" else 56)
		var circle: bool = k != "⌫"
		b.add_theme_stylebox_override("normal", _round(Color(1, 1, 1, 0.14 if circle else 0.0), 90))
		b.add_theme_stylebox_override("hover", _round(Color(1, 1, 1, 0.14 if circle else 0.0), 90))
		b.add_theme_stylebox_override("pressed", _round(Color(1, 1, 1, 0.4 if circle else 0.1), 90))
		b.pressed.connect(_on_key.bind(k))
		grid.add_child(b)

	if data.get_script_constant_map().has("CODE_HINT"):
		var hint := _label(data.CODE_HINT, 34, Color(TEXT, 0.55))
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -230
		hint.offset_bottom = -170
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pad.add_child(hint)


func _on_key(k: String) -> void:
	Sfx.play("click", -10.0, randf_range(0.9, 1.1))
	if k == "⌫":
		_code_entry = _code_entry.left(-1)
	elif _code_entry.length() < data.CODE.length():
		_code_entry += k
	for i in _dots.get_child_count():
		var filled := i < _code_entry.length()
		(_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.9 if filled else 0.0), 17, Color(1, 1, 1, 0.9), 3))
	if _code_entry.length() == data.CODE.length():
		if _code_entry == data.CODE:
			Sfx.play("unlock", -6.0)
			await get_tree().create_timer(0.25).timeout
			_unlock()
		else:
			Sfx.play("error", -6.0)
			viewed.emit("wrong_code:" + _code_entry)
			_shake(_dots)
			_code_entry = ""
			await get_tree().create_timer(0.35).timeout
			for d in _dots.get_children():
				(d as Panel).add_theme_stylebox_override("panel", _round(Color(1, 1, 1, 0.0), 17, Color(1, 1, 1, 0.9), 3))


func _unlock() -> void:
	is_locked = false
	unlocked.emit()
	if data.APPS.is_empty():
		_clear_screen()
		return
	show_home()


# --- Home screen ------------------------------------------------------------

func show_home() -> void:
	_clear_screen()
	var home := Control.new()
	home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(home)
	_wallpaper(home, 0.65)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.set_anchors_preset(Control.PRESET_TOP_WIDE)
	grid.offset_top = 220
	grid.offset_left = 60
	grid.offset_right = -60
	grid.add_theme_constant_override("h_separation", 50)
	grid.add_theme_constant_override("v_separation", 60)
	home.add_child(grid)
	for app in data.APPS:
		grid.add_child(_app_icon(app))
	_slide_in(home, true)


func _app_icon(app: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 190)
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = app["color"]
	b.add_theme_stylebox_override("normal", _round(col, 48))
	b.add_theme_stylebox_override("hover", _round(col, 48))
	b.add_theme_stylebox_override("pressed", _round(col.darkened(0.25), 48))
	var glyph := Control.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_glyph.bind(glyph, app["glyph"]))
	b.add_child(glyph)
	var badge := _unread(app["id"])
	if badge > 0:
		var dot := _label(str(badge), 34, Color.WHITE)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_stylebox_override("normal", _round(Color(0.95, 0.25, 0.25), 32))
		dot.position = Vector2(140, -16)
		dot.size = Vector2(64, 64)
		b.add_child(dot)
	b.pressed.connect(open_app.bind(app["id"]))
	box.add_child(b)
	var t := _label(app["title"], 32, TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 190
	t.clip_text = true
	box.add_child(t)
	return box


func _unread(app_id: String) -> int:
	if app_id != "messages":
		return 0
	var n := 0
	for c in _chats:
		n += int(c["unread"])
	return n


func _draw_glyph(c: Control, kind: String) -> void:
	var s := c.size
	var m := s * 0.5
	var w := Color.WHITE
	match kind:
		"chat":
			c.draw_circle(m + Vector2(0, -6), 52, w)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-34, 30), m + Vector2(-50, 62), m + Vector2(-6, 40)]), w)
		"notes":
			c.draw_rect(Rect2(m - Vector2(50, 60), Vector2(100, 120)), w)
			for i in 4:
				c.draw_line(m + Vector2(-34, -32 + i * 22), m + Vector2(34, -32 + i * 22), Color(0.95, 0.78, 0.25), 6)
		"news":
			c.draw_rect(Rect2(m - Vector2(60, 50), Vector2(120, 100)), w)
			c.draw_rect(Rect2(m - Vector2(46, 36), Vector2(40, 32)), Color(0.85, 0.25, 0.3))
			for i in 3:
				c.draw_line(m + Vector2(4, -30 + i * 18), m + Vector2(46, -30 + i * 18), Color(0.85, 0.25, 0.3), 6)
			c.draw_line(m + Vector2(-46, 20), m + Vector2(46, 20), Color(0.85, 0.25, 0.3), 6)
		"voice":
			for i in 7:
				var h: float = [20.0, 50.0, 80.0, 40.0, 70.0, 30.0, 16.0][i]
				c.draw_line(m + Vector2(-60 + i * 20, -h * 0.5), m + Vector2(-60 + i * 20, h * 0.5), w, 10)
		"photo":
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_circle(m + Vector2(cos(a), sin(a)) * 30, 24, Color(1, 1, 1, 0.75))
			c.draw_circle(m, 18, w)


# --- Apps ---------------------------------------------------------------------

func open_app(id: String) -> void:
	Sfx.play("click", -12.0)
	viewed.emit("app:" + id)
	match id:
		"messages":
			_push(_chat_list())
		"notes":
			_push(_list_view("Заметки", data.NOTES, func(n: Dictionary) -> Array: return [n["title"], n["date"]], _open_note))
		"news":
			_push(_list_view("Новости", data.NEWS, func(n: Dictionary) -> Array: return [n["title"], "%s · %s" % [n["source"], n["time"]]], _open_news))
		"voicemail":
			_push(_list_view("Голосовые", data.VOICEMAIL, func(n: Dictionary) -> Array: return [n["from"], "%s · %s" % [n["time"], n["length"]]], _open_voicemail))
		"photos":
			_push(_photo_grid())


func _chat_list() -> Control:
	var v := _app_view("Сообщения")
	var list: VBoxContainer = v.get_meta("list")
	for c in _chats:
		var last: Array = c["messages"][-1]
		var row := _row(c["name"], last[1], last[2], c["color"], int(c["unread"]))
		row.pressed.connect(_open_chat.bind(c))
		list.add_child(row)
	return v


func _open_chat(chat: Dictionary) -> void:
	viewed.emit("chat:" + chat["id"])
	chat["unread"] = 0
	var v := _app_view(chat["name"])
	var list: VBoxContainer = v.get_meta("list")
	list.add_theme_constant_override("separation", 14)
	for m in chat["messages"]:
		if m[0] == "day":
			var d := _label(m[1], 30, SUB)
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			d.custom_minimum_size.y = 70
			d.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			list.add_child(d)
		else:
			list.add_child(_bubble(m[1], m[2], m[0] == "me"))
	_push(v)
	# Conversations open at the newest message, like a real messenger.
	var scroll: ScrollContainer = v.get_meta("scroll")
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _bubble(text: String, time: String, mine: bool) -> Control:
	var row := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	var col := _accent.darkened(0.15) if mine else CARD.lightened(0.08)
	var sb := _round(col, 40)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	var l := _label(text, 42, Color(0.08, 0.06, 0.06) if mine else TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(width + 6.0, 700.0)
	box.add_child(l)
	var t := _label(time, 26, Color(0.1, 0.08, 0.08, 0.6) if mine else SUB)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(t)
	if mine:
		row.add_child(spacer)
		row.add_child(panel)
	else:
		row.add_child(panel)
		row.add_child(spacer)
	return row


func _open_note(n: Dictionary) -> void:
	viewed.emit("note:" + n["id"])
	_push(_text_view(n["title"], n["date"], n["body"]))


func _open_news(n: Dictionary) -> void:
	viewed.emit("news:" + n["id"])
	_push(_text_view(n["title"], "%s · %s" % [n["source"], n["time"]], n["body"]))


func _open_voicemail(n: Dictionary) -> void:
	viewed.emit("vm:" + n["id"])
	var v := _app_view(n["from"])
	var list: VBoxContainer = v.get_meta("list")
	list.add_theme_constant_override("separation", 40)
	var meta := _label("%s · %s" % [n["time"], n["length"]], 34, SUB)
	list.add_child(meta)
	var wave := Control.new()
	wave.custom_minimum_size = Vector2(900, 160)
	var progress := {"t": 0.0}
	wave.draw.connect(func() -> void:
		var bars := 40
		for i in bars:
			var h := 20.0 + 110.0 * absf(sin(i * 1.7) * cos(i * 0.6))
			var played: bool = float(i) / bars < float(progress["t"])
			wave.draw_line(Vector2(20 + i * 22, 80 - h * 0.5), Vector2(20 + i * 22, 80 + h * 0.5), _accent if played else Color(1, 1, 1, 0.25), 10))
	list.add_child(wave)
	var text := _label("", 44, TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 940
	list.add_child(text)
	_push(v)
	# "Playing" the message: the waveform fills and the transcript types itself out.
	var full: String = n["transcript"]
	text.text = full
	text.visible_characters = 0
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		progress["t"] = k
		text.visible_characters = int(full.length() * k)
		wave.queue_redraw(), 0.0, 1.0, maxf(2.5, full.length() / 22.0))


func _photo_grid() -> Control:
	var v := _app_view("Фото")
	var list: VBoxContainer = v.get_meta("list")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	for p in data.PHOTOS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(312, 312)
		b.focus_mode = Control.FOCUS_NONE
		_no_style(b)
		var img := TextureRect.new()
		img.texture = load(p["path"])
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(img)
		b.clip_contents = true
		b.pressed.connect(_open_photo.bind(p))
		grid.add_child(b)
	return v


func _open_photo(p: Dictionary) -> void:
	viewed.emit("photo:" + p["id"])
	var v := _app_view("")
	var list: VBoxContainer = v.get_meta("list")
	list.add_theme_constant_override("separation", 30)
	var tex: Texture2D = load(p["path"])
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(960, 960.0 * tex.get_height() / tex.get_width())
	list.add_child(img)
	var cap := _label(p["caption"], 44, TEXT)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size.x = 940
	list.add_child(cap)
	list.add_child(_label(p["meta"], 32, SUB))
	_push(v)


# --- Generic views -------------------------------------------------------------

## A full-screen app page with a header (back button + title) and a scrolling list.
func _app_view(title: String) -> Control:
	var v := Control.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_child(bg)

	var back := Button.new()
	back.text = "‹ Назад"
	back.focus_mode = Control.FOCUS_NONE
	back.position = Vector2(30, STATUS_H)
	back.custom_minimum_size = Vector2(260, 100)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_size_override("font_size", 44)
	back.add_theme_color_override("font_color", _accent)
	back.add_theme_color_override("font_pressed_color", _accent.darkened(0.3))
	back.add_theme_color_override("font_hover_color", _accent)
	_no_style(back)
	back.pressed.connect(_pop)
	v.add_child(back)

	var t := _label(title, 46, TEXT)
	t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	t.offset_top = STATUS_H + 22
	t.offset_left = 280
	t.offset_right = -280
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	v.add_child(t)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = STATUS_H + 120
	scroll.offset_bottom = -60
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	v.set_meta("list", list)
	v.set_meta("scroll", scroll)
	return v


func _list_view(title: String, items: Array, describe: Callable, on_open: Callable) -> Control:
	var v := _app_view(title)
	var list: VBoxContainer = v.get_meta("list")
	for item in items:
		var d: Array = describe.call(item)
		var row := _row(d[0], d[1], "", Color(0, 0, 0, 0), 0)
		row.pressed.connect(on_open.bind(item))
		list.add_child(row)
	return v


func _text_view(title: String, subtitle: String, body: String) -> Control:
	var v := _app_view("")
	var list: VBoxContainer = v.get_meta("list")
	list.add_theme_constant_override("separation", 26)
	var t := _label(title, 60, TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 940
	list.add_child(t)
	list.add_child(_label(subtitle, 32, SUB))
	var b := _label(body, 44, Color(TEXT, 0.92))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 940
	b.add_theme_constant_override("line_spacing", 10)
	list.add_child(b)
	return v


## A tappable list row: optional avatar, a title, a grey second line, time, badge.
func _row(title: String, subtitle: String, time: String, avatar: Color, unread: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 170)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", _round(Color(1, 1, 1, 0.06), 20))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.add_theme_constant_override("separation", 30)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	if avatar.a > 0.0:
		var av := Control.new()
		av.custom_minimum_size = Vector2(120, 120)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.draw.connect(func() -> void:
			av.draw_circle(Vector2(60, 60), 60, avatar)
			var f := get_theme_default_font()
			var letter := title.left(1)
			var sz := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 56)
			av.draw_string(f, Vector2(60 - sz.x * 0.5, 60 + 20), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color.WHITE))
		h.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var t := _label(title, 46, TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(t)
	if time != "":
		top.add_child(_label(time, 30, SUB))
	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bottom)
	var s := _label(subtitle, 36, SUB)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.clip_text = true
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom.add_child(s)
	if unread > 0:
		var u := _label(str(unread), 30, Color.WHITE)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		u.custom_minimum_size = Vector2(56, 0)
		u.add_theme_stylebox_override("normal", _round(_accent.darkened(0.1), 28))
		bottom.add_child(u)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.06)
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -2
	line.offset_left = 150 if avatar.a > 0.0 else 0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(line)
	return b


func _notice_card(app: String, text: String, time: String) -> Control:
	var p := PanelContainer.new()
	var sb := _round(Color(0.12, 0.13, 0.17, 0.78), 36)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var a := _label(app, 36, TEXT)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(a)
	top.add_child(_label(time, 30, SUB))
	var t := _label(text, 38, Color(TEXT, 0.88))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 880
	v.add_child(t)
	return p


# --- Navigation ---------------------------------------------------------------

func _push(view: Control) -> void:
	_screen.add_child(view)
	_stack.append(view)
	_slide_in(view, false)


func _pop() -> void:
	Sfx.play("click", -14.0)
	if _stack.is_empty():
		return
	var view: Control = _stack.pop_back()
	var tw := view.create_tween()
	tw.tween_property(view, "position:x", W, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(view.queue_free)


func _slide_in(view: Control, fade: bool) -> void:
	if fade:
		view.modulate.a = 0.0
		view.create_tween().tween_property(view, "modulate:a", 1.0, 0.35)
	else:
		view.position.x = W
		view.create_tween().tween_property(view, "position:x", 0.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _clear_screen() -> void:
	for c in _screen.get_children():
		c.queue_free()
	_stack.clear()


# --- Helpers ------------------------------------------------------------------

func _wallpaper(parent: Control, darken: float) -> void:
	if data.WALLPAPER != "":
		var img := TextureRect.new()
		img.texture = load(data.WALLPAPER)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(img)
	else:
		var g := Gradient.new()
		g.colors = PackedColorArray([_accent.darkened(0.35), Color(0.18, 0.12, 0.3), Color(0.05, 0.05, 0.1)])
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.2, 0.0)
		tex.fill_to = Vector2(0.8, 1.0)
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(img)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, darken)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


func _label(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _round(color: Color, radius: int, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	return sb


func _no_style(b: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())


func _shake(node: Control) -> void:
	var x := node.position.x
	var tw := node.create_tween()
	for i in 4:
		tw.tween_property(node, "position:x", x + (24 if i % 2 == 0 else -24), 0.05)
	tw.tween_property(node, "position:x", x, 0.05)
