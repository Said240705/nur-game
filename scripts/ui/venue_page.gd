extends Control
## Managing one business: yesterday's report, staff, stock, prices,
## advertising, renovation, and selling it. Rebuilt after every decision.

signal closed
signal changed

const Data := preload("res://scripts/game/data.gd")
const Venue := preload("res://scripts/game/venue.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const TouchScroll := preload("res://scripts/ui/touch_scroll.gd")
const CARD := Color("#171a26")
const GREEN := Color("#3ee08f")
const RED := Color("#ff5c6c")

var state: RefCounted
var v: Dictionary

var _scroll: ScrollContainer
var _labels := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#0d0e15")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll = TouchScroll.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rebuild()


func rebuild() -> void:
	var keep := _scroll.scroll_vertical
	for c in _scroll.get_children():
		c.queue_free()
	_labels.clear()
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 20)
	_scroll.add_child(box)
	box.add_child(UI.spacer(20))
	_build_top(box)
	_build_report(box)
	_build_staff(box)
	if Venue.uses_stock(v):
		_build_stock(box)
	_build_prices(box)
	_build_ads(box)
	_build_reno(box)
	_build_sell(box)
	box.add_child(UI.spacer(60))
	await get_tree().process_frame
	_scroll.scroll_vertical = keep


# --- Building blocks ---------------------------------------------------------------

func _card(box: VBoxContainer, title: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 30)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(36)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(2)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 28
	sb.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", sb)
	m.add_child(card)
	box.add_child(m)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	card.add_child(inner)
	if title != "":
		var t := UI.label(title, 40, UI.GOLD, 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		inner.add_child(t)
	return inner


func _line(box: Control, left: String, right: String, color := Color.WHITE, size_px := 34) -> Label:
	var h := HBoxContainer.new()
	var a := UI.label(left, size_px, UI.SUB, 600)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.label(right, size_px, color, 800)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	h.add_child(b)
	box.add_child(h)
	return b


func _small_button(text: String, color: Color, on_press: Callable, w := 110.0) -> Button:
	var b := UI.pill_button(text, color, on_press)
	b.custom_minimum_size = Vector2(w, 90)
	b.add_theme_font_size_override("font_size", 40)
	return b


func _act(ok: bool, good_sound := "up") -> void:
	Sfx.play(good_sound if ok else "no", -4.0 if ok else -6.0)
	if ok:
		changed.emit()
		rebuild()


# --- Sections ----------------------------------------------------------------------

func _build_top(box: VBoxContainer) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 30)
	m.add_theme_constant_override("margin_right", 30)
	box.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	m.add_child(h)
	var back := UI.flat_button("‹", 90, UI.GOLD, func() -> void: closed.emit())
	back.custom_minimum_size = Vector2(90, 140)
	h.add_child(back)
	var b := Venue.kind(v)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(140, 140)
	icon.draw.connect(func() -> void: Icons.tile(icon, b["id"], Rect2(Vector2.ZERO, icon.size), b["color"]))
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var name := UI.label(b["name"], 46, Color.WHITE, 900)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(name)
	var d := Venue.district(v)
	var where := UI.label("%s · %s помещение" % [d["name"], Data.SIZE_NAMES[Data.plot(v["plot"])["size"]]], 30, UI.SUB, 600)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(where)
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(400, 44)
	stars.draw.connect(func() -> void:
		Icons.stars(stars, Vector2(0, 22), v["rating"], 5, 18)
		stars.draw_string(UI.font(800), Vector2(230, 34), "%.1f" % v["rating"], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#ffd447")))
	col.add_child(stars)
	var why := Venue.blocker(v)
	var status := _card(box, "")
	var st := UI.label(why if why != "" else "Работает", 38, RED if why != "" else GREEN, 800)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(st)
	_line(status, "Поток людей в районе", "%d в день" % int(d["traffic"]), Color.WHITE, 30)
	var fit_text: String = ["плохо", "так себе", "хорошо", "отлично"][clampi(int(Venue.fit(v) * 3.99), 0, 3)]
	_line(status, "Подходит району", fit_text, GREEN if Venue.fit(v) >= 0.75 else Color("#ffb347"), 30)
	_line(status, "Могут прийти сегодня", "≈%d %s" % [int(Venue.demand(v, state.boost() * (1.0 + state.prestige()))), b["client"]], Color.WHITE, 30)
	_line(status, "Персонал обслужит", "%d %s" % [int(Venue.capacity(v)), b["client"]], Color.WHITE, 30)


func _build_report(box: VBoxContainer) -> void:
	var r: Dictionary = v["report"]
	var c := _card(box, "Вчера")
	if r.is_empty():
		var l := UI.label("Отчёт появится после первого рабочего дня.", 32, UI.SUB, 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		c.add_child(l)
		return
	var client: String = Venue.kind(v)["client"]
	_line(c, "Обслужено", "%d из %d %s" % [int(r["served"]), int(r["want"]), client])
	if r["lost"] >= 1.0:
		_line(c, "Ушли без покупки", "%d" % int(r["lost"]), RED)
	_line(c, "Выручка", "+" + Data.money(r["revenue"]), GREEN)
	if Venue.uses_stock(v):
		_line(c, "Товар (себестоимость)", "−" + Data.money(r["goods"]), RED)
	_line(c, "Зарплаты", "−" + Data.money(r["salaries"]), RED)
	_line(c, "Аренда", "−" + Data.money(r["rent"]), RED)
	_line(c, "Электричество", "−" + Data.money(r["power"]), RED)
	_line(c, "Вода", "−" + Data.money(r["water"]), RED)
	if r["ads"] > 0.0:
		_line(c, "Реклама", "−" + Data.money(r["ads"]), RED)
	var p: float = r["profit"]
	_line(c, "Прибыль", ("+" if p >= 0.0 else "") + Data.money(p), GREEN if p >= 0.0 else RED, 42)


func _build_staff(box: VBoxContainer) -> void:
	var c := _card(box, "Персонал")
	var b := Venue.kind(v)
	for role in Data.roles(b):
		var id: String = role["id"]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := UI.label(role["name"], 38, Color.WHITE, 800)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(name)
		var what := ""
		match role["kind"]:
			"serve":
				what = "обслуживает %s %s в день" % [_num(role["cap"]), b["client"]]
			"quality":
				what = "поднимает рейтинг"
			"manager":
				what = "сам закупает товар, +рейтинг" if Venue.uses_stock(v) else "+рейтинг"
		var sub := UI.label("%s · %s в день" % [what, Data.money(role["salary"])], 28, UI.SUB, 500)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size.x = 440
		col.add_child(sub)
		h.add_child(col)
		h.add_child(_small_button("−", Color("#8f96b8"), func() -> void: _act(state.hire(v, id, -1), "click")))
		var n := UI.label(str(v["staff"].get(id, 0)), 46, Color.WHITE, 900)
		n.custom_minimum_size.x = 70
		h.add_child(n)
		h.add_child(_small_button("+", UI.GOLD, func() -> void: _act(state.hire(v, id, 1))))
		c.add_child(h)
	_line(c, "Зарплаты в день", Data.money(Venue.salaries(v)), Color.WHITE, 32)


func _build_stock(box: VBoxContainer) -> void:
	var c := _card(box, "Склад")
	var per_day := maxf(1.0, v["expect"] if v["expect"] > 0.0 else minf(Venue.demand(v), Venue.capacity(v)))
	_line(c, "Запас", "на %d %s ≈ %.1f дн." % [int(v["stock"]), Venue.kind(v)["client"], v["stock"] / per_day], Color.WHITE)
	if Venue.has_manager(v):
		var l := UI.label("Управляющий сам докупает товар, когда остаётся мало.", 28, GREEN, 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.add_child(l)
	for days in [3, 7]:
		var r := Venue.restock(v, days)
		var label := "Закупить на %d дн. · %s%s" % [days, Data.money(r["cost"]), "  (−10%)" if days >= 7 else ""]
		var btn := UI.pill_button(label, UI.GOLD if days == 3 else Color("#8f96b8"), func() -> void: _act(state.buy_stock(v, days)))
		btn.custom_minimum_size = Vector2(0, 110)
		btn.add_theme_font_size_override("font_size", 36)
		c.add_child(btn)


func _build_prices(box: VBoxContainer) -> void:
	var c := _card(box, "Цены")
	_line(c, "Средний чек", Data.money(Venue.ticket(v)), Color.WHITE)
	var row := _segments(Data.PRICES.size(), v["price_lv"], func(i: int) -> String: return ["−−", "−", "=", "+", "++"][i],
		func(i: int) -> void:
			v["price_lv"] = i
			_act(true, "click"))
	c.add_child(row)
	var hint := UI.label("%s: дешевле — больше клиентов, дороже — больше с каждого, но рейтинг страдает без хорошего ремонта." % Data.PRICES[v["price_lv"]]["name"], 28, UI.SUB, 500)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_child(hint)


func _build_ads(box: VBoxContainer) -> void:
	var c := _card(box, "Реклама")
	var row := _segments(Data.ADS.size(), v["ads"], func(i: int) -> String: return Data.ADS[i]["name"],
		func(i: int) -> void:
			v["ads"] = i
			_act(true, "click"))
	c.add_child(row)
	_line(c, "Клиентов больше", "+%d%%" % roundi((Data.ADS[v["ads"]]["effect"] - 1.0) * 100.0), GREEN, 30)
	_line(c, "Стоит в день", Data.money(Venue.ads_cost(v)), Color.WHITE, 30)


func _build_reno(box: VBoxContainer) -> void:
	var c := _card(box, "Ремонт")
	_line(c, "Сейчас", Data.RENOVATION[v["reno"]]["name"], Color.WHITE)
	var cost: float = state.renovation_cost(v)
	if cost < 0.0:
		var l := UI.label("Лучше уже некуда.", 30, GREEN, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		c.add_child(l)
		return
	var next: Dictionary = Data.RENOVATION[v["reno"] + 1]
	var l := UI.label("«%s»: клиентов ×%.2f, рейтинг выше. Закрыто на %d дн. — зарплаты и аренду всё равно платишь." % [
		next["name"], next["appeal"] / Data.RENOVATION[v["reno"]]["appeal"], next["days"]], 28, UI.SUB, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_child(l)
	var btn := UI.pill_button("Сделать ремонт · " + Data.money(cost), UI.GOLD, func() -> void: _act(state.renovate(v), "fanfare"))
	btn.custom_minimum_size = Vector2(0, 110)
	btn.add_theme_font_size_override("font_size", 38)
	if v["closed"] > 0:
		btn.modulate.a = 0.4
	c.add_child(btn)


func _build_sell(box: VBoxContainer) -> void:
	var c := _card(box, "")
	var btn := UI.pill_button("Продать бизнес · " + Data.money(Venue.value(v)), Color("#ff5c6c"), func() -> void:
		state.sell_venue(v)
		Sfx.play("coin")
		changed.emit()
		closed.emit())
	btn.custom_minimum_size = Vector2(0, 110)
	btn.add_theme_font_size_override("font_size", 38)
	c.add_child(btn)


func _segments(n: int, current: int, label: Callable, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in n:
		var on := i == current
		var b := UI.pill_button(label.call(i), UI.GOLD if on else Color("#2a2f45"), func() -> void: on_pick.call(i))
		b.custom_minimum_size = Vector2(0, 90)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 30)
		if not on:
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(k, Color.WHITE)
		row.add_child(b)
	return row


func _num(x: float) -> String:
	return str(int(x)) if x >= 10.0 else String.num(x, 1)
