extends Control
## A mobile browser showing the city news site. Light browser chrome (address
## bar, bottom toolbar) around a newspaper-styled site: masthead, rubrics, hero
## story, ads, "read also" and comments, which is where clues like to hide.

const UI := preload("res://scripts/phone/ui.gd")
const CHROME := Color(0.96, 0.96, 0.97)
const PAGE := Color(1, 1, 1)
const INK := Color(0.08, 0.08, 0.09)
const GREY := Color(0.45, 0.46, 0.5)
const RED := Color(0.62, 0.07, 0.1)
const LINK := Color(0.1, 0.4, 0.85)
const TOOLBAR_H := 140.0

var phone: Control
var light := true


func build() -> void:
	_page(self, func(list: VBoxContainer) -> void: _front_page(list))


## Browser chrome around a scrolling page whose content `fill` creates.
func _page(root: Control, fill: Callable) -> void:
	var site: Dictionary = phone.data.SITE
	root.add_child(UI.full(UI.rect(PAGE)))
	var list := UI.scroller(root, phone.STATUS_H + 120, TOOLBAR_H)
	list.add_theme_constant_override("separation", 0)
	fill.call(list)
	list.add_child(_footer(site))

	var top := UI.rect(CHROME)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = phone.STATUS_H + 120
	root.add_child(top)
	var bar := UI.panel(Color(0.88, 0.88, 0.9), 30, 0)
	bar.position = Vector2(40, phone.STATUS_H + 10)
	bar.custom_minimum_size = Vector2(1000, 92)
	root.add_child(bar)
	var lock := Control.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.custom_minimum_size = Vector2(1000, 92)
	lock.draw.connect(func() -> void:
		var f := UI.sans(500)
		var text: String = site["domain"]
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
		var x := (1000.0 - w) * 0.5
		lock.draw_rect(Rect2(x - 44, 42, 24, 20), INK)
		lock.draw_arc(Vector2(x - 32, 42), 9, PI, TAU, 10, INK, 4)
		lock.draw_string(f, Vector2(x, 60), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, INK))
	bar.add_child(lock)

	var tools := UI.rect(CHROME)
	tools.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tools.offset_top = -TOOLBAR_H
	root.add_child(tools)
	var line := UI.rect(Color(0, 0, 0, 0.1))
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -TOOLBAR_H
	line.offset_bottom = -TOOLBAR_H + 2
	root.add_child(line)
	var back := UI.text_button("‹", 96, LINK, phone.pop, UI.sans(300))
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 50
	back.offset_top = -TOOLBAR_H - 6
	back.offset_right = 170
	back.offset_bottom = -10
	root.add_child(back)
	var icons := Control.new()
	icons.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	icons.offset_top = -TOOLBAR_H
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.draw.connect(func() -> void:
		var y := TOOLBAR_H * 0.45
		var c := Color(0.6, 0.62, 0.66)
		icons.draw_string(UI.sans(300), Vector2(270, y + 30), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, c)
		icons.draw_rect(Rect2(516, y - 26, 48, 52), LINK, false, 4)
		icons.draw_line(Vector2(540, y - 44), Vector2(540, y + 6), LINK, 4)
		icons.draw_line(Vector2(526, y - 30), Vector2(540, y - 44), LINK, 4)
		icons.draw_line(Vector2(554, y - 30), Vector2(540, y - 44), LINK, 4)
		icons.draw_arc(Vector2(780, y), 28, 0, TAU, 24, LINK, 4)
		icons.draw_rect(Rect2(966, y - 26, 44, 44), LINK, false, 4)
		icons.draw_rect(Rect2(980, y - 38, 44, 44), LINK, false, 4))
	root.add_child(icons)


func _masthead(site: Dictionary, small := false) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var band := UI.panel(RED, 0, 0)
	band.custom_minimum_size = Vector2(1080, 110 if small else 190)
	var name := UI.label(site["name"], 50 if small else 80, Color.WHITE, UI.serif(true))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(name)
	box.add_child(band)
	if not small:
		var info := UI.panel(Color(0.97, 0.94, 0.94), 0, 18)
		var row := HBoxContainer.new()
		info.add_child(row)
		var date := UI.label(site["date"], 32, GREY)
		date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(UI.spacer(0))
		row.add_child(date)
		row.add_child(UI.label(site["weather"], 32, GREY))
		box.add_child(info)
		var rubrics := UI.panel(PAGE, 0, 22)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 46)
		rubrics.add_child(r)
		for i in site["rubrics"].size():
			r.add_child(UI.label(site["rubrics"][i], 34, RED if i == 0 else INK, UI.sans(600 if i == 0 else 500)))
		box.add_child(rubrics)
		box.add_child(_rule())
	return box


func _rule() -> Control:
	var r := UI.rect(Color(0, 0, 0, 0.1))
	r.custom_minimum_size = Vector2(1080, 2)
	return r


func _front_page(list: VBoxContainer) -> void:
	var site: Dictionary = phone.data.SITE
	list.add_child(_masthead(site))
	var articles: Array = site["articles"]
	var hero: Dictionary = articles[0]
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 18)
	card.add_child(UI.cover(load(hero["image"]), Vector2(1080, 600)))
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 50)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 14)
	pad.add_child(text)
	text.add_child(UI.label(hero["rubric"].to_upper(), 30, RED, UI.sans(700)))
	text.add_child(UI.label(hero["title"], 60, INK, UI.serif(true), 980))
	text.add_child(UI.label(hero["lead"], 40, GREY, UI.serif(), 980))
	text.add_child(UI.label("%s · %s" % [hero["author"], hero["time"]], 30, GREY))
	card.add_child(pad)
	card.add_child(UI.spacer(30))
	list.add_child(UI.tappable(card, _open_article.bind(hero), Color(0, 0, 0, 0.04)))
	list.add_child(_rule())
	list.add_child(_ad(site["ad"]))
	list.add_child(_rule())
	for a in articles.slice(1):
		if a.get("archive", false):
			continue
		list.add_child(_headline_row(a))
		list.add_child(_rule())


func _headline_row(a: Dictionary) -> Control:
	var row := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		row.add_theme_constant_override("margin_" + side, 40 if side in ["top", "bottom"] else 50)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	row.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label(a["rubric"].to_upper(), 28, RED, UI.sans(700)))
	v.add_child(UI.label(a["title"], 44, INK, UI.serif(true), 620))
	v.add_child(UI.label(a["time"], 28, GREY))
	if a.has("image"):
		h.add_child(UI.cover(load(a["image"]), Vector2(300, 220)))
	UI.tap_area(row, _open_article.bind(a), Color(0, 0, 0, 0.04))
	return row


func _ad(ad: Dictionary) -> Control:
	var wrap := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		wrap.add_theme_constant_override("margin_" + side, 40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	wrap.add_child(v)
	v.add_child(UI.label("РЕКЛАМА", 24, GREY, UI.sans(600)))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.09, 0.08), 18, 40))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	p.add_child(inner)
	inner.add_child(UI.label(ad["title"], 52, Color(1.0, 0.85, 0.55), UI.serif(true), 900))
	inner.add_child(UI.label(ad["text"], 36, Color(1, 1, 1, 0.8), null, 900))
	inner.add_child(UI.label(ad["cta"], 34, Color(1.0, 0.7, 0.35), UI.sans(700)))
	v.add_child(p)
	UI.tap_area(p, func() -> void: phone.emit_viewed("ad:" + ad["id"]), Color(1, 1, 1, 0.05))
	return wrap


func _open_article(a: Dictionary) -> void:
	phone.emit_viewed("news:" + a["id"])
	var v := Control.new()
	_page(v, func(list: VBoxContainer) -> void: _article(list, a))
	phone.push(v, true)


func _article(list: VBoxContainer, a: Dictionary) -> void:
	var site: Dictionary = phone.data.SITE
	list.add_child(_masthead(site, true))
	var pad := MarginContainer.new()
	for side in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, 50 if side != "top" else 40)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	pad.add_child(v)
	list.add_child(pad)
	v.add_child(UI.label(a["rubric"].to_upper(), 30, RED, UI.sans(700)))
	v.add_child(UI.label(a["title"], 66, INK, UI.serif(true), 980))
	v.add_child(UI.label("%s · %s · %s просмотров" % [a["author"], a["time"], a.get("views", "1 204")], 30, GREY, null, 980))
	if a.has("image"):
		list.add_child(UI.spacer(20))
		list.add_child(UI.cover(load(a["image"]), Vector2(1080, 620)))
		var cap := MarginContainer.new()
		cap.add_theme_constant_override("margin_left", 50)
		cap.add_theme_constant_override("margin_right", 50)
		cap.add_theme_constant_override("margin_top", 12)
		cap.add_child(UI.label(a.get("caption", ""), 30, GREY, UI.serif(), 980))
		list.add_child(cap)
	var body := MarginContainer.new()
	for side in ["left", "right", "top"]:
		body.add_theme_constant_override("margin_" + side, 50 if side != "top" else 30)
	var b := UI.label(a["body"], 44, INK, UI.serif(), 980)
	b.add_theme_constant_override("line_spacing", 12)
	body.add_child(b)
	list.add_child(body)
	list.add_child(UI.spacer(30))

	if a.has("ad"):
		list.add_child(_ad(site["ad"]))
	if a.has("related"):
		list.add_child(_section("Читайте также"))
		for id in a["related"]:
			for other in site["articles"]:
				if other["id"] == id:
					list.add_child(_headline_row(other))
					list.add_child(_rule())
	list.add_child(_section("Комментарии"))
	if a.has("comments"):
		for c in a["comments"]:
			list.add_child(_comment(c))
	else:
		var closed := MarginContainer.new()
		closed.add_theme_constant_override("margin_left", 50)
		closed.add_theme_constant_override("margin_bottom", 30)
		closed.add_child(UI.label("Комментарии к этой статье закрыты.", 36, GREY))
		list.add_child(closed)


func _section(title: String) -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 50 if side in ["left", "right"] else 26)
	var v := VBoxContainer.new()
	m.add_child(v)
	var bar := UI.rect(RED)
	bar.custom_minimum_size = Vector2(120, 6)
	v.add_child(bar)
	v.add_child(UI.label(title.to_upper(), 36, INK, UI.sans(700)))
	return m


## A reader comment; hidden ones can be revealed with a tap.
func _comment(c: Dictionary) -> Control:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 50 if side in ["left", "right"] else 18)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	m.add_child(h)
	var av := Control.new()
	av.custom_minimum_size = Vector2(90, 90)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Color.from_hsv(float(hash(c["user"]) % 360) / 360.0, 0.35, 0.75)
	av.draw.connect(func() -> void:
		av.draw_circle(Vector2(45, 45), 45, col)
		var f := UI.sans(600)
		var letter: String = c["user"].left(1).to_upper()
		av.draw_string(f, Vector2(31, 62), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE))
	h.add_child(av)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UI.label("%s   %s" % [c["user"], c["time"]], 32, GREY, UI.sans(600)))
	var text := UI.label(c["text"], 40, INK, null, 840)
	v.add_child(text)
	if c.get("hidden", false):
		text.text = "Комментарий скрыт модератором. Показать"
		text.add_theme_color_override("font_color", LINK)
		UI.tap_area(m, func() -> void:
			text.text = c["text"]
			text.add_theme_color_override("font_color", INK)
			phone.emit_viewed("comment:" + c["user"]), Color(0, 0, 0, 0.04))
	return m


func _footer(site: Dictionary) -> Control:
	var p := UI.panel(Color(0.12, 0.12, 0.13), 0, 50)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label(site["name"], 40, Color.WHITE, UI.serif(true)))
	v.add_child(UI.label(site["footer"], 28, Color(1, 1, 1, 0.5), null, 980))
	return p
