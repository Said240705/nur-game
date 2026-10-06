extends Control
## The photo library: black, with a Photos / Albums switch, month headers and a
## full-screen viewer whose "info" sheet shows when and where a photo was taken.
## Albums include a locked one, a door left closed for the second part.

const UI := preload("res://scripts/phone/ui.gd")
const BG := Color(0, 0, 0)
const TEXT := Color(0.96, 0.96, 0.98)
const SUB := Color(0.58, 0.6, 0.66)
const BLUE := Color(0.32, 0.6, 1.0)
const SHEET := Color(0.11, 0.11, 0.13)

var phone: Control
var light := false

var _content: Control
var _tabs: Array[Button] = []


func build() -> void:
	add_child(UI.full(UI.rect(BG)))
	var back := UI.text_button("‹", 90, BLUE, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	add_child(back)
	var title := UI.label("Медиатека", 72, TEXT, UI.sans(700))
	title.position = Vector2(60, phone.STATUS_H + 110)
	add_child(title)

	var seg := UI.panel(Color(1, 1, 1, 0.1), 30, 6)
	seg.position = Vector2(60, phone.STATUS_H + 220)
	add_child(seg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	seg.add_child(h)
	for t in ["Фото", "Альбомы"]:
		var b := UI.text_button(t, 36, TEXT, _show_tab.bind(t), UI.sans(600))
		b.custom_minimum_size = Vector2(470, 76)
		h.add_child(b)
		_tabs.append(b)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_top = phone.STATUS_H + 340
	add_child(_content)
	_show_tab("Фото")


func _show_tab(t: String) -> void:
	for b in _tabs:
		var on := b.text == t
		b.add_theme_stylebox_override("normal", UI.box(Color(1, 1, 1, 0.22) if on else Color(0, 0, 0, 0), 26))
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
	for c in _content.get_children():
		c.queue_free()
	var holder := Control.new()
	_content.add_child(UI.full(holder))
	var list := UI.scroller(holder, 0, 40)
	if t == "Фото":
		_photos(list)
	else:
		_albums(list)


func _photos(list: VBoxContainer) -> void:
	var by_month := {}
	var order: Array[String] = []
	for p in phone.data.PHOTOS:
		if p.get("album", "") == "hidden":
			continue
		var m: String = p["month"]
		if not by_month.has(m):
			by_month[m] = []
			order.append(m)
		by_month[m].append(p)
	for m in order:
		var head := UI.label(m, 44, TEXT, UI.sans(700))
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 40)
		pad.add_theme_constant_override("margin_top", 30)
		pad.add_theme_constant_override("margin_bottom", 16)
		pad.add_child(head)
		list.add_child(pad)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		list.add_child(grid)
		for p in by_month[m]:
			var thumb := UI.cover(load(p["path"]), Vector2(356, 356))
			grid.add_child(UI.tappable(thumb, _open.bind(p)))


func _albums(list: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 40)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 40)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_child(grid)
	list.add_child(pad)
	for album in phone.data.ALBUMS:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		var cover: Control
		var photos: Array = phone.data.PHOTOS.filter(func(p: Dictionary) -> bool: return p.get("album", "") == album["id"] or album["id"] == "all")
		if album.get("locked", false):
			cover = _locked_cover()
		elif photos.is_empty():
			cover = UI.panel(Color(0.12, 0.12, 0.14), 24, 0)
			cover.custom_minimum_size = Vector2(480, 480)
		else:
			cover = UI.cover(load(photos[0]["path"]), Vector2(480, 480))
		v.add_child(cover)
		v.add_child(UI.label(album["title"], 40, TEXT, UI.sans(600)))
		v.add_child(UI.label("—" if album.get("locked", false) else str(photos.size()), 34, SUB))
		grid.add_child(UI.tappable(v, _open_album.bind(album, photos)))


func _locked_cover() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(480, 480)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.custom_minimum_size), Color(0.1, 0.1, 0.12))
		var m := Vector2(240, 250)
		c.draw_rect(Rect2(m - Vector2(60, 10), Vector2(120, 100)), SUB)
		c.draw_arc(m - Vector2(0, 10), 42, PI, TAU, 16, SUB, 14))
	return c


func _open_album(album: Dictionary, photos: Array) -> void:
	if album.get("locked", false):
		Sfx.play("error", -8.0)
		phone.emit_viewed("album:" + album["id"])
		return
	if not photos.is_empty():
		_open(photos[0])


func _open(p: Dictionary) -> void:
	phone.emit_viewed("photo:" + p["id"])
	var v := Control.new()
	v.add_child(UI.full(UI.rect(BG)))
	var tex: Texture2D = load(p["path"])
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.offset_top = phone.STATUS_H + 140
	img.offset_bottom = -180
	v.add_child(img)

	var top := UI.rect(Color(0, 0, 0, 0.6))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = phone.STATUS_H + 130
	v.add_child(top)
	var back := UI.text_button("‹", 90, BLUE, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	v.add_child(back)
	var when := UI.label(p["date"], 40, TEXT, UI.sans(600))
	when.set_anchors_preset(Control.PRESET_TOP_WIDE)
	when.offset_top = phone.STATUS_H + 8
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(when)
	var clock := UI.label(p["time"], 32, SUB)
	clock.set_anchors_preset(Control.PRESET_TOP_WIDE)
	clock.offset_top = phone.STATUS_H + 62
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(clock)

	var sheet := _info_sheet(p)
	sheet.visible = false
	v.add_child(sheet)

	var bottom := UI.rect(Color(0, 0, 0, 0.6))
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -170
	v.add_child(bottom)
	var info := UI.text_button("i", 54, BLUE, func() -> void:
		sheet.visible = not sheet.visible
		if sheet.visible:
			phone.emit_viewed("photo_info:" + p["id"]), UI.sans(400))
	info.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0), 46, 0, BLUE, 4))
	info.add_theme_stylebox_override("hover", UI.box(Color(0, 0, 0, 0), 46, 0, BLUE, 4))
	info.add_theme_stylebox_override("pressed", UI.box(Color(0.3, 0.6, 1.0, 0.25), 46, 0, BLUE, 4))
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.offset_left = -46
	info.offset_right = 46
	info.offset_top = -140
	info.offset_bottom = -48
	v.add_child(info)
	phone.push(v)


func _info_sheet(p: Dictionary) -> Control:
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UI.box(SHEET, 40, 50))
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_top = -900
	sheet.offset_bottom = -170
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	sheet.add_child(v)
	v.add_child(UI.label(p["caption"], 44, TEXT, UI.sans(500), 960))
	v.add_child(UI.label("%s · %s" % [p["date"], p["time"]], 34, SUB))
	var map := Control.new()
	map.custom_minimum_size = Vector2(980, 260)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(func() -> void:
		# A tiny stylised map: streets, a river and a pin on the place.
		map.draw_rect(Rect2(Vector2.ZERO, map.custom_minimum_size), Color(0.17, 0.19, 0.2))
		map.draw_line(Vector2(0, 190), Vector2(980, 120), Color(0.2, 0.32, 0.45), 40)
		for i in 7:
			map.draw_line(Vector2(i * 160, 0), Vector2(i * 160 + 60, 260), Color(0.28, 0.3, 0.32), 10)
		map.draw_line(Vector2(0, 70), Vector2(980, 90), Color(0.28, 0.3, 0.32), 14)
		var pin := Vector2(560, 110)
		map.draw_circle(pin, 30, Color(0.95, 0.3, 0.3))
		map.draw_circle(pin, 11, Color.WHITE))
	v.add_child(map)
	v.add_child(UI.label(p["place"], 38, TEXT, UI.sans(600), 960))
	v.add_child(UI.label(p["device"], 32, SUB))
	return sheet
