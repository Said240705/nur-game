extends Control
## A believable smartphone built from Controls: lock screen (tap or passcode),
## home screen and navigation. Each app has its own look and lives in
## scripts/phone/apps/; everything shown comes from a data script
## (scripts/story/*_phone.gd), so each phone is just data.
## The director listens to `viewed` to move the story along.

signal viewed(key: String)
signal unlocked

const UI := preload("res://scripts/phone/ui.gd")
const APPS := {
	"messages": preload("res://scripts/phone/apps/messenger.gd"),
	"notes": preload("res://scripts/phone/apps/notes.gd"),
	"browser": preload("res://scripts/phone/apps/browser.gd"),
	"photos": preload("res://scripts/phone/apps/gallery.gd"),
	"voicemail": preload("res://scripts/phone/apps/voice.gd"),
}
const BG := Color(0.035, 0.04, 0.055)
const TEXT := Color(0.95, 0.95, 0.97)
const SUB := Color(0.6, 0.62, 0.68)
const STATUS_H := 110.0
const W := 1080.0

var data: Script
var is_locked := true
var accent := Color.WHITE
## Mutable copy of the chats, so read state can change during play.
var chats: Array = []

var _status_time: Label
var _status_batt: Label
var _screen: Control
var _stack: Array[Control] = []
var _code_entry := ""
var _dots: HBoxContainer
var _battery := 100
## Minutes since midnight shown on the clock; it runs while the phone is on screen.
var _minutes := 0.0
var _lock_time: Label


func setup(phone_data: Script) -> void:
	data = phone_data
	accent = data.ACCENT
	_battery = data.LOCK["battery"]
	chats = data.CHATS.duplicate(true)
	var hm: PackedStringArray = data.LOCK["time"].split(":")
	_minutes = int(hm[0]) * 60 + int(hm[1])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var t := Theme.new()
	t.default_font = UI.sans()
	t.default_font_size = 44
	theme = t

	var bg := UI.rect(BG)
	add_child(UI.full(bg))
	_screen = Control.new()
	_screen.name = "PhoneScreen"
	add_child(UI.full(_screen))
	_build_status_bar()
	_show_lock()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var before := clock_text()
	_minutes = fmod(_minutes + delta / 60.0, 24.0 * 60.0)
	if clock_text() != before:
		_status_time.text = clock_text()
		if is_instance_valid(_lock_time):
			_lock_time.text = clock_text()


func clock_text() -> String:
	return "%02d:%02d" % [int(_minutes) / 60, int(_minutes) % 60]


func battery() -> int:
	return _battery


func set_battery(value: int) -> void:
	_battery = value
	_status_batt.text = "%d%%" % value


func has_const(name: String) -> bool:
	return data.get_script_constant_map().has(name)


# --- Status bar -------------------------------------------------------------

func _build_status_bar() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = STATUS_H
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_status_time = UI.label(clock_text(), 40, TEXT, UI.sans(600))
	_status_time.position = Vector2(70, 38)
	bar.add_child(_status_time)
	_status_batt = UI.label("%d%%" % _battery, 38, TEXT, UI.sans(600))
	_status_batt.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_batt.offset_left = -220
	_status_batt.offset_right = -70
	_status_batt.offset_top = 38
	_status_batt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status_batt)


## Dark text on light apps (notes, browser), light text elsewhere.
func _status_style(light_background: bool) -> void:
	var c := Color(0.1, 0.1, 0.12) if light_background else TEXT
	_status_time.add_theme_color_override("font_color", c)
	_status_batt.add_theme_color_override("font_color", c)


# --- Lock screen ------------------------------------------------------------

func _show_lock() -> void:
	_clear_screen()
	var lock := Control.new()
	_screen.add_child(UI.full(lock))
	_wallpaper(lock, 0.5)

	var date := UI.label(data.LOCK["date"], 46, Color(TEXT, 0.9), UI.sans(500))
	date.set_anchors_preset(Control.PRESET_TOP_WIDE)
	date.offset_top = 190
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(date)
	var time := UI.label(clock_text(), 210, TEXT, UI.sans(600))
	_lock_time = time
	time.set_anchors_preset(Control.PRESET_TOP_WIDE)
	time.offset_top = 230
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(time)

	var list := VBoxContainer.new()
	list.set_anchors_preset(Control.PRESET_TOP_WIDE)
	list.offset_top = 560
	list.offset_left = 50
	list.offset_right = -50
	list.add_theme_constant_override("separation", 20)
	lock.add_child(list)
	for n in data.LOCK["notifications"]:
		list.add_child(_notice_card(n[0], n[1], n[2]))

	var hint := UI.label("Нажми, чтобы разблокировать" if data.CODE == "" else "Нажми, чтобы ввести код", 38, Color(TEXT, 0.75))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -330
	hint.offset_bottom = -270
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.add_child(hint)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.35, 1.2)
	tw.tween_property(hint, "modulate:a", 1.0, 1.2)

	UI.tap_area(lock, _on_lock_tapped, Color(0, 0, 0, 0))


func _notice_card(app: String, text: String, time: String) -> Control:
	var p := PanelContainer.new()
	var sb := UI.box(Color(0.12, 0.13, 0.17, 0.8), 38, 30)
	sb.content_margin_left = 38
	sb.content_margin_right = 38
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var a := UI.label(app, 36, TEXT, UI.sans(600))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(a)
	top.add_child(UI.label(time, 30, SUB))
	v.add_child(UI.label(text, 38, Color(TEXT, 0.88), null, 880))
	return p


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
	_screen.add_child(UI.full(pad))
	_wallpaper(pad, 0.8)

	var title := UI.label("Введите код-пароль", 52, TEXT, UI.sans(500))
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
		d.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0), 17, 0, Color(1, 1, 1, 0.9), 3))
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
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(180, 180)
			grid.add_child(gap)
			continue
		var b := Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(180, 180)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UI.sans(400))
		b.add_theme_font_size_override("font_size", 74 if k != "⌫" else 56)
		var circle: bool = k != "⌫"
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.14 if circle else 0.0), 90))
		b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.14 if circle else 0.0), 90))
		b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.4 if circle else 0.1), 90))
		b.pressed.connect(_on_key.bind(k))
		grid.add_child(b)

	if has_const("CODE_HINT"):
		var hint := UI.label(data.CODE_HINT, 34, Color(TEXT, 0.55))
		hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -330
		hint.offset_bottom = -270
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pad.add_child(hint)


func _on_key(k: String) -> void:
	Sfx.play("click", -10.0, randf_range(0.9, 1.1))
	if k == "⌫":
		_code_entry = _code_entry.left(-1)
	elif _code_entry.length() < data.CODE.length():
		_code_entry += k
	_paint_dots()
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
			_paint_dots()


func _paint_dots() -> void:
	for i in _dots.get_child_count():
		var filled := i < _code_entry.length()
		(_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.9 if filled else 0.0), 17, 0, Color(1, 1, 1, 0.9), 3))


func _unlock() -> void:
	is_locked = false
	unlocked.emit()
	if data.APPS.is_empty():
		_clear_screen()
		return
	show_home()


# --- Home screen ------------------------------------------------------------

func show_home(fade := true) -> void:
	_clear_screen()
	_status_style(false)
	var home := Control.new()
	_screen.add_child(UI.full(home))
	_wallpaper(home, 0.6)
	_lock_time = null

	var grid := GridContainer.new()
	grid.name = "AppGrid"
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
	if fade:
		home.modulate.a = 0.0
		home.create_tween().tween_property(home, "modulate:a", 1.0, 0.35)


func _app_icon(app: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 190)
	b.focus_mode = Control.FOCUS_NONE
	var col: Color = app["color"]
	b.add_theme_stylebox_override("normal", UI.box(col, 48))
	b.add_theme_stylebox_override("hover", UI.box(col, 48))
	b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.25), 48))
	var glyph := Control.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(_draw_glyph.bind(glyph, app["glyph"]))
	b.add_child(UI.full(glyph))
	var badge := _unread(app["id"])
	if badge > 0:
		var dot := UI.label(str(badge), 34, Color.WHITE, UI.sans(600))
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_stylebox_override("normal", UI.box(Color(0.95, 0.25, 0.25), 32))
		dot.position = Vector2(140, -16)
		dot.size = Vector2(64, 64)
		b.add_child(dot)
	b.pressed.connect(open_app.bind(app["id"]))
	box.add_child(b)
	var t := UI.label(app["title"], 32, TEXT, UI.sans(500))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 190
	t.clip_text = true
	box.add_child(t)
	return box


func _unread(app_id: String) -> int:
	if app_id != "messages":
		return 0
	var n := 0
	for c in chats:
		n += int(c["unread"])
	return n


func _draw_glyph(c: Control, kind: String) -> void:
	var m := c.size * 0.5
	var w := Color.WHITE
	match kind:
		"chat":
			c.draw_circle(m + Vector2(0, -6), 52, w)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-34, 30), m + Vector2(-50, 62), m + Vector2(-6, 40)]), w)
		"notes":
			c.draw_rect(Rect2(m - Vector2(50, 60), Vector2(100, 120)), w)
			for i in 4:
				c.draw_line(m + Vector2(-34, -32 + i * 22), m + Vector2(34, -32 + i * 22), Color(0.95, 0.78, 0.25), 6)
		"browser":
			c.draw_arc(m, 56, 0, TAU, 48, w, 8, true)
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-14, -14), m + Vector2(40, -40), m + Vector2(14, 14)]), Color(0.95, 0.3, 0.3))
			c.draw_colored_polygon(PackedVector2Array([m + Vector2(-14, -14), m + Vector2(-40, 40), m + Vector2(14, 14)]), w)
		"voice":
			var hs := [20.0, 50.0, 80.0, 40.0, 70.0, 30.0, 16.0]
			for i in 7:
				var h: float = hs[i]
				c.draw_line(m + Vector2(-60 + i * 20, -h * 0.5), m + Vector2(-60 + i * 20, h * 0.5), w, 10)
		"photo":
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_circle(m + Vector2(cos(a), sin(a)) * 30, 24, Color(1, 1, 1, 0.75))
			c.draw_circle(m, 18, w)


# --- Navigation ---------------------------------------------------------------

func open_app(id: String) -> void:
	Sfx.play("click", -12.0)
	viewed.emit("app:" + id)
	if not APPS.has(id):
		return
	var app: Control = APPS[id].new()
	app.phone = self
	app.build()
	push(app, app.get("light") == true)


## Show a page on top of the current one, sliding in from the right.
func push(view: Control, light := false) -> void:
	_screen.add_child(UI.full(view))
	view.set_meta("light", light)
	_stack.append(view)
	_status_style(light)
	view.position.x = W
	view.create_tween().tween_property(view, "position:x", 0.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func pop() -> void:
	Sfx.play("click", -14.0)
	if _stack.is_empty():
		return
	var view: Control = _stack.pop_back()
	_status_style(_stack.back().get_meta("light", false) if not _stack.is_empty() else false)
	# What lies underneath may be stale (read chats, badges): refresh it.
	if _stack.is_empty():
		_refresh_home_badges()
	elif _stack.back().has_method("refresh"):
		_stack.back().refresh()
	var tw := view.create_tween()
	tw.tween_property(view, "position:x", W, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(view.queue_free)


## Rebuild the icon grid on the home page (the bottom of the stack) in place.
func _refresh_home_badges() -> void:
	for c in _screen.get_children():
		if c.is_queued_for_deletion():
			continue
		var grid := c.find_child("AppGrid", true, false) as GridContainer
		if grid:
			for icon in grid.get_children():
				icon.queue_free()
			for app in data.APPS:
				grid.add_child(_app_icon(app))


func emit_viewed(key: String) -> void:
	viewed.emit(key)


# --- Live messages --------------------------------------------------------------

func _chat(chat_id: String) -> Dictionary:
	for c in chats:
		if c["id"] == chat_id:
			return c
	return {}


## The open conversation with this contact, if it is the page on top.
func _open_chat_view(chat_id: String) -> Control:
	if _stack.is_empty() or not _stack.back().has_meta("chat_id"):
		return null
	return _stack.back() if _stack.back().get_meta("chat_id") == chat_id else null


## "Typing…" under the contact's name while their message is on its way.
func set_typing(chat_id: String, on: bool) -> void:
	var chat := _chat(chat_id)
	if on:
		chat["status"] = "печатает…"
	elif chat["status"] == "печатает…":
		chat["status"] = "в сети"
	var view := _open_chat_view(chat_id)
	if view:
		var l: Label = view.get_meta("status")
		l.text = chat["status"]
		l.add_theme_color_override("font_color", accent if on else Color(0.36, 0.62, 0.98))


## A message arriving right now: straight into the open chat, otherwise a
## banner at the top and an unread badge.
func receive(chat_id: String, text: String) -> void:
	var chat := _chat(chat_id)
	var row := ["them", text, clock_text()]
	chat["messages"].append(row)
	chat["status"] = "в сети"
	Sfx.play("ping", -6.0)
	var view := _open_chat_view(chat_id)
	if view:
		view.get_meta("append").call(row)
		return
	chat["unread"] = int(chat["unread"]) + 1
	if _stack.is_empty():
		_refresh_home_badges()
	elif _stack.back().has_method("refresh"):
		_stack.back().refresh()
	_banner(chat, text)


func _banner(chat: Dictionary, text: String) -> void:
	var card := _notice_card(chat["name"], text, "сейчас")
	card.position = Vector2(40, -260)
	card.custom_minimum_size.x = W - 80
	add_child(card)
	var tap := UI.tap_area(card, func() -> void:
		card.queue_free()
		_open_from_banner(chat["id"]), Color(1, 1, 1, 0.08))
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := card.create_tween()
	tw.tween_property(card, "position:y", STATUS_H + 10, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(4.0)
	tw.tween_property(card, "position:y", -260.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(card.queue_free)


func _open_from_banner(chat_id: String) -> void:
	if not is_locked and not _open_chat_view(chat_id):
		open_app("messages")
		_stack.back()._open_chat(_chat(chat_id))


## Jump straight into a conversation from wherever the phone is.
func open_chat(chat_id: String) -> void:
	if is_locked or _open_chat_view(chat_id):
		return
	show_home(false)
	_open_from_banner(chat_id)


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
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(UI.full(img))
	else:
		var g := Gradient.new()
		g.colors = PackedColorArray([accent.darkened(0.35), Color(0.18, 0.12, 0.3), Color(0.05, 0.05, 0.1)])
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill_from = Vector2(0.2, 0.0)
		tex.fill_to = Vector2(0.8, 1.0)
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(UI.full(img))
	parent.add_child(UI.full(UI.rect(Color(0, 0, 0, darken))))


func _shake(node: Control) -> void:
	var x := node.position.x
	var tw := node.create_tween()
	for i in 4:
		tw.tween_property(node, "position:x", x + (24 if i % 2 == 0 else -24), 0.05)
	tw.tween_property(node, "position:x", x, 0.05)
