extends Node
## ОТ НУЛЯ ДО МИЛЛИАРДЕРА: the header with money and status, three tabs
## (work, business, property), life events with risky choices, hot deals on a
## timer, new statuses, bankruptcy, saving and money earned while away.

const State := preload("res://scripts/game/state.gd")
const Data := preload("res://scripts/game/data.gd")
const Events := preload("res://scripts/game/events.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const Save := preload("res://scripts/save.gd")
const TouchScroll := preload("res://scripts/ui/touch_scroll.gd")
const Contract := preload("res://scripts/game/contract.gd")
## One mini-game per job; the status decides which.
const JOBS := {
	"flyers": preload("res://scripts/work/flyers.gd"),
	"courier": preload("res://scripts/work/courier.gd"),
	"taxi": preload("res://scripts/work/taxi.gd"),
	"negotiation": preload("res://scripts/work/negotiation.gd"),
	"papers": preload("res://scripts/work/papers.gd"),
	"stocks": preload("res://scripts/work/stocks.gd"),
}

const BG := Color("#0d0e15")
const CARD := Color("#171a26")
const GREEN := Color("#3ee08f")
const RED := Color("#ff5c6c")
const HEADER_H := 380.0
const TABS_H := 190.0
## Seconds between life events and between hot deals (random within the range).
const EVENT_GAP := Vector2(22, 40)
const DEAL_GAP := Vector2(45, 80)
const DEAL_TIME := 15.0
## Money while away: at most two hours count, at half the usual rate.
const AWAY_CAP := 7200.0
const AWAY_RATE := 0.5

var s: RefCounted
var root: Control

var _rank: Label
var _day: Label
var _cash: Label
var _flow: Label
var _bar: Control
var _bar_label: Label
var _pages := {}
var _tab_buttons := {}
var _tab := "work"
var _refreshers: Array = []
var _deal_box: Control
var _deal := {}
var _modal: Control
var _job: Label
var _pay: Label
var _tip: Label

var _day_t := 0.0
var _event_t := 25.0
var _deal_t := 40.0
var _save_t := 0.0
var _refresh_t := 0.0
var _shown := 0.0
var _last_event := ""
var _rank_seen := 0
var _last_unix := 0.0


func _ready() -> void:
	var dev := OS.get_cmdline_user_args()
	var saved: Dictionary = {} if dev.size() > 0 else Save.get_value("life", {})
	s = State.from_dict(saved) if not saved.is_empty() else State.new()
	_shown = s.cash
	_rank_seen = s.rank()
	Sfx.sound_on = Save.get_value("sound", true)
	Sfx.music_on = Save.get_value("music", true)

	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_background.bind(bg))
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_pages()
	_build_header()
	_build_tabs()
	_build_deal()
	_show_tab("work")
	_last_unix = Time.get_unix_time_from_system()
	if not saved.is_empty():
		_welcome_back(_last_unix - float(saved.get("saved_at", _last_unix)))
	if dev.size() > 0:
		var tool: Node = load("res://scripts/dev/autoshot.gd").new()
		tool.setup(self, dev)
		add_child(tool)


# --- Clock ----------------------------------------------------------------------

func _process(delta: float) -> void:
	var unix := Time.get_unix_time_from_system()
	var gap := unix - _last_unix
	_last_unix = unix
	if gap > 30.0 and not s.bankrupt:
		_welcome_back(gap)
	_update_header(delta)
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		for r in _refreshers:
			r.call()
	if _modal or s.bankrupt:
		return
	_day_t += delta
	while _day_t >= Data.DAY:
		_day_t -= Data.DAY
		var change: float = s.next_day()
		if absf(change) >= 1.0:
			_float(("+" if change > 0.0 else "") + Data.money(change), Vector2(540, 250), GREEN if change > 0.0 else RED, 40)
		if s.bankrupt:
			_show_bankrupt()
			return
		_check_rank()
	_event_t -= delta
	if _event_t <= 0.0:
		_show_event()
	_tick_deal(delta)
	_save_t += delta
	if _save_t >= 2.0:
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	_save_t = 0.0
	if s and OS.get_cmdline_user_args().is_empty():
		Save.set_value("life", s.to_dict())
		Save.set_value("record", maxf(Save.get_value("record", 0.0), s.best_worth))


func _check_rank() -> void:
	var r: int = s.rank()
	if r > _rank_seen:
		_rank_seen = r
		_show_rank_up(r)
		_rebuild_pages()


# --- Background and header -------------------------------------------------------

func _draw_background(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), BG)
	# A warm glow behind the money, like light on gold.
	for i in 8:
		var k := 1.0 - i / 8.0
		c.draw_circle(Vector2(540, 160), 700 * k, Color(0.96, 0.77, 0.32, 0.012))


func _build_header() -> void:
	var h := Control.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	h.offset_bottom = HEADER_H
	var shade := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.11, 0.97)
	sb.corner_radius_bottom_left = 50
	sb.corner_radius_bottom_right = 50
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 30
	shade.add_theme_stylebox_override("panel", sb)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_rank = _at(h, UI.label("", 40, UI.GOLD, 800), Vector2(60, 40), Vector2(600, 56), HORIZONTAL_ALIGNMENT_LEFT)
	_day = _at(h, UI.label("", 36, UI.SUB, 600), Vector2(560, 40), Vector2(260, 56), HORIZONTAL_ALIGNMENT_RIGHT)
	_cash = _at(h, UI.label("", 112, Color.WHITE, 900), Vector2(56, 96), Vector2(900, 130), HORIZONTAL_ALIGNMENT_LEFT)
	UI.glow(_cash, Color(0.96, 0.77, 0.32, 0.35), 20)
	_flow = _at(h, UI.label("", 38, GREEN, 700), Vector2(60, 226), Vector2(960, 50), HORIZONTAL_ALIGNMENT_LEFT)
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.position = Vector2(60, 300)
	_bar.size = Vector2(960, 22)
	_bar.draw.connect(_draw_bar)
	h.add_child(_bar)
	_bar_label = _at(h, UI.label("", 30, UI.SUB, 600), Vector2(60, 326), Vector2(960, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_build_toggles(h)


func _at(parent: Control, l: Label, pos: Vector2, size: Vector2, align: HorizontalAlignment) -> Label:
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	parent.add_child(l)
	return l


func _update_header(delta: float) -> void:
	_shown = lerpf(_shown, s.cash, 1.0 - exp(-12.0 * delta))
	if absf(_shown - s.cash) < 1.0:
		_shown = s.cash
	_cash.text = Data.money(_shown)
	_cash.add_theme_color_override("font_color", RED if s.cash < 0.0 else Color.WHITE)
	var r: int = s.rank()
	_rank.text = Data.RANKS[r]["name"]
	_day.text = "День %d" % s.day
	if s.cash < 0.0:
		_flow.text = "ДОЛГ! До банкротства %d дн." % (Data.DEBT_DAYS - s.debt_days)
		_flow.add_theme_color_override("font_color", RED)
	else:
		var inc: float = s.daily_income()
		var cost: float = s.daily_costs()
		var text := "+%s в день" % Data.money(inc) if inc > 0.0 else "Пока нет дохода — работай и покупай бизнес"
		if cost > 0.0:
			text += "   −%s расходы" % Data.money(cost)
		if s.boost() != 1.0:
			text += "   ×%.2f" % s.boost()
		_flow.text = text
		_flow.add_theme_color_override("font_color", GREEN if inc >= cost else Color("#ffb347"))
	if r + 1 < Data.RANKS.size():
		var next: Dictionary = Data.RANKS[r + 1]
		_bar_label.text = "Капитал %s  ·  до статуса «%s» — %s" % [Data.money(s.worth()), next["name"], Data.money(next["worth"])]
	else:
		_bar_label.text = "Капитал %s  ·  вершина достигнута!" % Data.money(s.worth())
	_bar.queue_redraw()


func _draw_bar() -> void:
	var r: int = s.rank()
	var k := 1.0
	if r + 1 < Data.RANKS.size():
		var lo: float = Data.RANKS[r]["worth"]
		var hi: float = Data.RANKS[r + 1]["worth"]
		k = clampf((s.worth() - lo) / (hi - lo), 0.0, 1.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(11)
	_bar.draw_style_box(back, Rect2(Vector2.ZERO, _bar.size))
	if k > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = UI.GOLD
		fill.set_corner_radius_all(11)
		fill.shadow_color = Color(0.96, 0.77, 0.32, 0.5)
		fill.shadow_size = 10
		_bar.draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(22.0, _bar.size.x * k), _bar.size.y)))


func _build_toggles(h: Control) -> void:
	for kind in ["music", "sound"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(84, 84)
		b.position = Vector2(850 if kind == "music" else 950, 26)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.07)
		sb.set_corner_radius_all(42)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.draw.connect(_draw_toggle.bind(b, kind))
		b.pressed.connect(func() -> void:
			if kind == "sound":
				Sfx.sound_on = not Sfx.sound_on
				Save.set_value("sound", Sfx.sound_on)
			else:
				Sfx.set_music(not Sfx.music_on)
				Save.set_value("music", Sfx.music_on)
			Sfx.play("click")
			b.queue_redraw())
		h.add_child(b)


func _draw_toggle(b: Button, kind: String) -> void:
	var on: bool = Sfx.sound_on if kind == "sound" else Sfx.music_on
	var col := Color(1, 1, 1, 0.85 if on else 0.3)
	var c := Vector2(42, 42)
	if kind == "sound":
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -7), c + Vector2(-8, -7), c + Vector2(4, -18),
			c + Vector2(4, 18), c + Vector2(-8, 7), c + Vector2(-18, 7)]), col)
		if on:
			b.draw_arc(c + Vector2(4, 0), 11, -0.9, 0.9, 12, col, 4, true)
			b.draw_arc(c + Vector2(4, 0), 19, -0.9, 0.9, 16, col, 4, true)
	else:
		b.draw_line(c + Vector2(-7, 12), c + Vector2(-7, -16), col, 5)
		b.draw_line(c + Vector2(11, 8), c + Vector2(11, -20), col, 5)
		b.draw_line(c + Vector2(-7, -16), c + Vector2(11, -20), col, 6)
		b.draw_circle(c + Vector2(-12, 12), 7, col)
		b.draw_circle(c + Vector2(6, 8), 7, col)
	if not on:
		b.draw_line(c + Vector2(-24, -24), c + Vector2(24, 24), Color(1, 0.4, 0.5, 0.9), 5)


# --- Tabs -------------------------------------------------------------------------

func _build_tabs() -> void:
	var bar := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.11, 0.98)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.border_width_top = 2
	bar.add_theme_stylebox_override("panel", sb)
	root.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TABS_H
	var items := [["work", "Работа"], ["biz", "Бизнес"], ["prop", "Имущество"]]
	for i in items.size():
		var id: String = items[i][0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.position = Vector2(i * 360, 0)
		b.size = Vector2(360, TABS_H)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.draw.connect(_draw_tab.bind(b, id, items[i][1]))
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			_show_tab(id))
		bar.add_child(b)
		_tab_buttons[id] = b


func _draw_tab(b: Button, id: String, title: String) -> void:
	var on := _tab == id
	var col := UI.GOLD if on else Color(1, 1, 1, 0.45)
	var icon: String = {"work": "coin", "biz": "bank", "prop": "house"}[id]
	if on:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.96, 0.77, 0.32, 0.12)
		glow.set_corner_radius_all(40)
		b.draw_style_box(glow, Rect2(40, 18, 280, 150))
	Icons.glyph(b, icon, Vector2(180, 74), 0.62)
	if not on:
		b.draw_rect(Rect2(110, 30, 140, 90), Color(0.07, 0.07, 0.11, 0.55))
	var f := UI.font(700)
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	b.draw_string(f, Vector2(180 - w * 0.5, 152), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, col)


func _show_tab(id: String) -> void:
	_tab = id
	for k in _pages:
		_pages[k].visible = k == id
	for k in _tab_buttons:
		_tab_buttons[k].queue_redraw()


func _build_pages() -> void:
	for id in ["work", "biz", "prop"]:
		var page := Control.new()
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.offset_top = HEADER_H
		page.offset_bottom = -TABS_H
		_pages[id] = page
	_rebuild_pages()


func _rebuild_pages() -> void:
	_refreshers.clear()
	for id in _pages:
		for c in _pages[id].get_children():
			c.queue_free()
	_build_work(_pages["work"])
	_build_list(_pages["biz"], true)
	_build_list(_pages["prop"], false)


# --- Work -------------------------------------------------------------------------

func _build_work(page: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	page.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 30
	box.offset_right = -30
	box.offset_top = 30
	box.offset_bottom = -20
	var r: Dictionary = Data.RANKS[s.rank()]
	_job = UI.label(r["job"], 50, Color.WHITE, 800)
	box.add_child(_job)
	_pay = UI.label("%s за удачу" % Data.money(r["pay"]), 34, GREEN, 700)
	box.add_child(_pay)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(36)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(frame)
	var game: Control = JOBS[r["game"]].new()
	game.pay = r["pay"]
	if r["game"] == "negotiation":
		game.title = "Клиент выбирает франшизу" if s.rank() == 3 else "Клиент решает, нанять ли тебя"
	game.earned.connect(_on_earned)
	frame.add_child(game)
	var tip_card := PanelContainer.new()
	tip_card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.25)))
	_tip = UI.label("", 32, Color.WHITE, 600)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_card.add_child(_tip)
	box.add_child(tip_card)
	_refreshers.append(_refresh_work)
	_refresh_work()


func _on_earned(amount: float, at: Vector2, note: String) -> void:
	s.cash += amount
	if absf(amount) >= 1.0:
		_float(("+" if amount > 0.0 else "") + Data.money(amount), at, GREEN if amount > 0.0 else RED, 60)
		Sfx.play("coin" if amount > 0.0 else "no", -8.0 if amount > 0.0 else -4.0, randf_range(0.95, 1.1))
		Input.vibrate_handheld(10 if amount > 0.0 else 40)
	elif note != "":
		Sfx.play("no", -10.0)
	if note != "":
		_float(note, at + Vector2(0, -70), Color.WHITE, 40)


func _refresh_work() -> void:
	_tip.text = _advice()


## What to do next, in a sentence.
func _advice() -> String:
	if s.cash < 0.0:
		return "Ты в долгах! Работай или жди дохода — иначе через несколько дней банкротство."
	if s.businesses.is_empty():
		if s.cash >= Data.BUSINESSES[0]["price"]:
			return "Хватает на первый бизнес! Открой вкладку «Бизнес» и купи ларёк с шаурмой."
		return "Работай — зарабатывай. Накопи %s на свой первый бизнес." % Data.money(Data.BUSINESSES[0]["price"])
	if s.owned.is_empty():
		return "Купи жильё или транспорт во вкладке «Имущество»: статус увеличивает доход всех бизнесов."
	return "Улучшай бизнесы, покупай новые и рискуй с умом: события могут озолотить — или разорить."


# --- Business and property lists ------------------------------------------------------

func _card_box(border := Color(1, 1, 1, 0.06)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(36)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	return sb


func _build_list(page: Control, business: bool) -> void:
	var scroll: ScrollContainer = TouchScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	page.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 22)
	scroll.add_child(box)
	box.add_child(UI.spacer(30))
	if business:
		var shown := 0
		for b in Data.BUSINESSES:
			# Owned ones, plus the next two to aim for.
			if not s.businesses.has(b["id"]):
				shown += 1
				if shown > 2:
					box.add_child(_teaser(b["name"], b["price"]))
					break
			box.add_child(_business_card(b))
	else:
		for kind in [["home", "Жильё"], ["ride", "Транспорт"]]:
			var head := UI.label(kind[1], 44, UI.SUB, 800)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 60)
			pad.add_child(head)
			box.add_child(pad)
			for p in Data.PROPERTY:
				if p["kind"] == kind[0]:
					box.add_child(_property_card(p))
	box.add_child(UI.spacer(40))


func _row(card_child: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_child(card_child)
	return m


func _business_card(b: Dictionary) -> Control:
	var id: String = b["id"]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	card.add_child(h)
	h.add_child(_icon(id, b["color"]))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var name := UI.label(b["name"], 42, Color.WHITE, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var line := UI.label("", 34, GREEN, 700)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(line)
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(300, 26)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(func() -> void:
		var lvl: int = s.businesses.get(id, 0)
		for i in Data.MAX_LEVEL:
			dots.draw_circle(Vector2(12 + i * 30, 13), 10, UI.GOLD if i < lvl else Color(1, 1, 1, 0.1)))
	v.add_child(dots)
	var btn := UI.pill_button("", UI.GOLD, func() -> void:
		var ok: bool
		if not s.businesses.has(id):
			if s.cash >= b["price"]:
				_show_contract(Contract.make(id, b["price"], false))
			else:
				Sfx.play("no", -6.0)
			return
		ok = s.upgrade_business(id)
		if ok:
			Sfx.play("up")
			_rebuild_pages()
			_check_rank()
		else:
			Sfx.play("no", -6.0))
	btn.custom_minimum_size = Vector2(250, 110)
	btn.add_theme_font_size_override("font_size", 34)
	h.add_child(btn)
	var refresh := func() -> void:
		var lvl: int = s.businesses.get(id, 0)
		line.add_theme_color_override("font_color", GREEN)
		if s.repairs.has(id):
			line.text = "На ремонте ещё %d дн. — дохода нет" % s.repairs[id]
			line.add_theme_color_override("font_color", RED)
			btn.text = "Улучшить\n" + Data.money(s.upgrade_cost(id))
			btn.modulate.a = 1.0 if s.cash >= s.upgrade_cost(id) else 0.4
		elif lvl == 0:
			line.text = "+%s в день" % Data.money(Data.income_at(b, 1))
			btn.text = "Купить\n" + Data.money(b["price"])
			btn.modulate.a = 1.0 if s.cash >= b["price"] else 0.4
		elif lvl >= Data.MAX_LEVEL:
			line.text = "+%s в день  ·  максимум" % Data.money(Data.income_at(b, lvl))
			btn.text = "МАКС"
			btn.modulate.a = 0.4
		else:
			line.text = "+%s → %s в день" % [Data.money(Data.income_at(b, lvl)), Data.money(Data.income_at(b, lvl + 1))]
			if s.rents.has(id):
				line.text += "  ·  аренда −%s" % Data.money(s.rents[id])
			btn.text = "Улучшить\n" + Data.money(s.upgrade_cost(id))
			btn.modulate.a = 1.0 if s.cash >= s.upgrade_cost(id) else 0.4
		dots.queue_redraw()
	refresh.call()
	_refreshers.append(refresh)
	return _row(card)


func _teaser(name: String, price: float) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box())
	var l := UI.label("Дальше: %s и ещё больше — от %s" % [name, Data.money(price)], 34, UI.SUB, 600)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(l)
	return _row(card)


func _property_card(p: Dictionary) -> Control:
	var id: String = p["id"]
	var card := PanelContainer.new()
	var has: bool = s.owned.has(id)
	card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.5) if has else Color(1, 1, 1, 0.06)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	card.add_child(h)
	h.add_child(_icon(id, Color("#3a3f5c") if not has else Color("#c8921d")))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name := UI.label(p["name"], 40, Color.WHITE, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var perks := UI.label("Статус: доход +%d%%" % roundi(p["prestige"] * 100.0), 32, GREEN, 700)
	perks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(perks)
	var cost := UI.label("Содержание: %s в день" % Data.money(p["upkeep"]) if p["upkeep"] > 0.0 else "Без расходов", 30, UI.SUB, 600)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(cost)
	if has:
		var mine := UI.label("Твоё", 40, UI.GOLD, 900)
		mine.custom_minimum_size = Vector2(250, 0)
		h.add_child(mine)
	else:
		var btn := UI.pill_button("Купить\n" + Data.money(p["price"]), UI.GOLD, func() -> void:
			if s.buy_property(id):
				Sfx.play("fanfare", -4.0)
				_rebuild_pages()
				_check_rank()
			else:
				Sfx.play("no", -6.0))
		btn.custom_minimum_size = Vector2(250, 110)
		btn.add_theme_font_size_override("font_size", 34)
		h.add_child(btn)
		_refreshers.append(func() -> void: btn.modulate.a = 1.0 if s.cash >= p["price"] else 0.4)
	return _row(card)


func _icon(id: String, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(140, 140)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void: Icons.tile(c, id, Rect2(Vector2.ZERO, c.size), color))
	return c


# --- Hot deals -------------------------------------------------------------------

func _build_deal() -> void:
	_deal_box = Control.new()
	_deal_box.visible = false
	root.add_child(_deal_box)
	_deal_box.position = Vector2(40, HEADER_H + 20)
	_deal_box.size = Vector2(1000, 170)
	_deal_box.draw.connect(_draw_deal)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_deal_box.add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(UI.guarded(_take_deal))


func _tick_deal(delta: float) -> void:
	if not _deal.is_empty():
		_deal["left"] -= delta
		_deal_box.queue_redraw()
		if _deal["left"] <= 0.0:
			_deal = {}
			_deal_box.visible = false
		return
	_deal_t -= delta
	if _deal_t > 0.0:
		return
	_deal_t = randf_range(DEAL_GAP.x, DEAL_GAP.y)
	var offers := []
	var budget := maxf(600.0, s.cash * 2.5)
	for b in Data.BUSINESSES:
		if not s.businesses.has(b["id"]) and b["price"] <= budget:
			offers.append({"kind": "biz", "item": b})
	for p in Data.PROPERTY:
		if not s.owned.has(p["id"]) and p["price"] <= budget:
			offers.append({"kind": "prop", "item": p})
	if offers.is_empty():
		return
	_deal = offers[randi() % offers.size()]
	_deal["off"] = randf_range(0.35, 0.6)
	_deal["price"] = roundf(_deal["item"]["price"] * (1.0 - _deal["off"]))
	_deal["left"] = DEAL_TIME
	_deal_box.visible = true
	Sfx.play("ding", -4.0)


func _draw_deal() -> void:
	if _deal.is_empty():
		return
	var r := Rect2(Vector2.ZERO, _deal_box.size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#2a1630")
	sb.set_corner_radius_all(36)
	sb.border_color = Color("#ff5fa2")
	sb.set_border_width_all(3)
	sb.shadow_color = Color(1, 0.37, 0.64, 0.4 + 0.2 * sin(Time.get_ticks_msec() / 150.0))
	sb.shadow_size = 24
	_deal_box.draw_style_box(sb, r)
	var item: Dictionary = _deal["item"]
	Icons.tile(_deal_box, item["id"], Rect2(22, 22, 126, 126), item.get("color", Color("#c8921d")))
	var f := UI.font(800)
	_deal_box.draw_string(f, Vector2(176, 62), "ГОРЯЩАЯ СДЕЛКА  −%d%%" % roundi(_deal["off"] * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#ff5fa2"))
	_deal_box.draw_string(f, Vector2(176, 112), "%s за %s" % [item["name"], Data.money(_deal["price"])], HORIZONTAL_ALIGNMENT_LEFT, 800, 40, Color.WHITE)
	var k: float = _deal["left"] / DEAL_TIME
	_deal_box.draw_rect(Rect2(176, 134, 780 * k, 10), Color("#ff5fa2"))


func _take_deal() -> void:
	if _deal.is_empty():
		return
	if _deal["kind"] == "biz":
		# Hot deals come with contracts too, and cheap ones hide traps more often.
		if s.cash >= _deal["price"]:
			var c := Contract.make(_deal["item"]["id"], _deal["price"], true)
			_deal = {}
			_deal_box.visible = false
			_show_contract(c)
		else:
			Sfx.play("no", -6.0)
			_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)
		return
	var ok: bool = s.buy_property(_deal["item"]["id"], _deal["price"])
	if ok:
		Sfx.play("fanfare", -2.0)
		_float("Куплено со скидкой!", Vector2(540, HEADER_H + 230), UI.GOLD, 54)
		_deal = {}
		_deal_box.visible = false
		_rebuild_pages()
		_check_rank()
	else:
		Sfx.play("no", -6.0)
		_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)


# --- Modal cards ----------------------------------------------------------------

func _open_modal() -> VBoxContainer:
	UI.modal_open = true
	_modal = Control.new()
	root.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.05, 0.78)
	_modal.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	var sb := _card_box(Color(0.96, 0.77, 0.32, 0.45))
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 54
	sb.content_margin_bottom = 54
	sb.set_corner_radius_all(50)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 40
	card.add_theme_stylebox_override("panel", sb)
	_modal.add_child(card)
	card.position = Vector2(50, root.size.y * 0.2)
	card.custom_minimum_size = Vector2(980, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	card.add_child(box)
	_modal.modulate.a = 0.0
	_modal.create_tween().tween_property(_modal, "modulate:a", 1.0, 0.3)
	return box


func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
	_modal = null
	UI.modal_open = false
	_rebuild_pages()


func _modal_text(box: VBoxContainer, text: String, size_px: int, color: Color, weight := 600) -> Label:
	var l := UI.label(text, size_px, color, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 870
	box.add_child(l)
	return l


func _modal_button(box: VBoxContainer, text: String, color: Color, on_press: Callable) -> void:
	var b := UI.pill_button(text, color, on_press)
	b.custom_minimum_size = Vector2(870, 130)
	b.add_theme_font_size_override("font_size", 42)
	box.add_child(b)
	# A card can pop up mid-tap on the coin: wait a moment before buttons
	# accept a press, so a choice is never made by accident.
	b.disabled = true
	b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("font_disabled_color", Color("#1a1040"))
	b.modulate.a = 0.5
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.disabled = false
			b.create_tween().tween_property(b, "modulate:a", 1.0, 0.2))


func _fill(text: String, e: Dictionary) -> String:
	var biz := ""
	if e.get("biz_id", "") != "":
		biz = Data.business(e["biz_id"])["name"]
	return text.replace("{amt}", Data.money(e["amount"])).replace("{biz}", biz)


func _show_event() -> void:
	var e: Dictionary = Events.pick(s, _last_event)
	_last_event = e["id"]
	Sfx.play("ding")
	var box := _open_modal()
	_modal_text(box, "СОБЫТИЕ", 32, UI.GOLD, 800)
	_modal_text(box, e["title"], 64, Color.WHITE, 900)
	_modal_text(box, _fill(e["text"], e), 42, Color("#d8dbe8"), 500)
	box.add_child(UI.spacer(20))
	var colors := [UI.GOLD, Color("#8f96b8")]
	for i in e["choices"].size():
		var choice: Dictionary = e["choices"][i]
		_modal_button(box, _fill(choice["label"], e), colors[i % 2], _choose.bind(e, choice))


func _choose(e: Dictionary, choice: Dictionary) -> void:
	var outcome: Dictionary = Events.roll(choice)
	var before: float = s.cash
	s.apply(outcome, e["amount"], e["biz_id"])
	var diff: float = s.cash - before
	if _modal:
		_modal.queue_free()
	_modal = null
	var box := _open_modal()
	var mult: float = outcome["boost"][0] if outcome.has("boost") else 1.0
	var lvl: int = outcome.get("level", 0)
	var good := diff > 0.0 or mult > 1.0 or lvl > 0
	var bad := diff < 0.0 or mult < 1.0 or lvl < 0
	_modal_text(box, e["title"], 40, UI.SUB, 800)
	_modal_text(box, _fill(outcome["text"], e), 52, Color.WHITE, 800)
	if absf(diff) >= 1.0:
		var l := _modal_text(box, ("+" if diff > 0.0 else "") + Data.money(diff), 96, GREEN if diff > 0.0 else RED, 900)
		UI.glow(l, Color(GREEN if diff > 0.0 else RED, 0.5), 18)
	if outcome.has("boost"):
		_modal_text(box, "Доход ×%.2f на %d дней" % [mult, outcome["boost"][1]], 40, GREEN if mult > 1.0 else RED, 700)
	box.add_child(UI.spacer(20))
	_modal_button(box, "Дальше", UI.GOLD, func() -> void:
		_event_t = randf_range(EVENT_GAP.x, EVENT_GAP.y)
		_close_modal()
		_check_rank())
	if good and not bad:
		Sfx.play("fanfare", -4.0)
	elif bad:
		Sfx.play("no", -2.0)


func _show_rank_up(r: int) -> void:
	if _modal:
		return
	Sfx.play("fanfare")
	var box := _open_modal()
	_modal_text(box, "НОВЫЙ СТАТУС", 34, UI.GOLD, 800)
	var name := _modal_text(box, Data.RANKS[r]["name"], 96, Color.WHITE, 900)
	UI.glow(name, Color(0.96, 0.77, 0.32, 0.6), 24)
	_modal_text(box, "Новая работа: %s — %s за удачу" % [Data.RANKS[r]["job"], Data.money(Data.RANKS[r]["pay"])], 40, Color("#d8dbe8"), 600)
	if r == Data.RANKS.size() - 1:
		_modal_text(box, "Ты сделал это: от нуля до миллиарда за %d дней!" % s.day, 44, GREEN, 800)
	box.add_child(UI.spacer(20))
	_modal_button(box, "Круто!", UI.GOLD, _close_modal)


func _show_bankrupt() -> void:
	_save()
	Sfx.play("no")
	var box := _open_modal()
	_modal_text(box, "БАНКРОТ", 96, RED, 900)
	_modal_text(box, "Долги не вернул — банк забрал всё. Но настоящие миллиардеры падали и не раз.", 42, Color("#d8dbe8"), 500)
	_modal_text(box, "Лучший капитал: %s   ·   Дней: %d" % [Data.money(s.best_worth), s.day], 38, UI.GOLD, 700)
	box.add_child(UI.spacer(20))
	_modal_button(box, "Начать заново", UI.GOLD, func() -> void:
		s = State.new()
		_shown = s.cash
		_rank_seen = 0
		_deal = {}
		_deal_box.visible = false
		_event_t = 25.0
		_save()
		_close_modal())


func _welcome_back(seconds: float) -> void:
	var t := minf(seconds, AWAY_CAP)
	var days := t / Data.DAY
	var earned: float = maxf(0.0, (s.daily_income() - s.daily_costs()) * days * AWAY_RATE)
	if earned < 1.0 or _modal:
		return
	s.cash += earned
	s.day += int(days)
	_shown = s.cash
	var box := _open_modal()
	_modal_text(box, "С возвращением!", 60, Color.WHITE, 900)
	_modal_text(box, "Пока тебя не было, бизнес заработал", 42, Color("#d8dbe8"), 500)
	var l := _modal_text(box, "+" + Data.money(earned), 110, GREEN, 900)
	UI.glow(l, Color(GREEN, 0.5), 20)
	box.add_child(UI.spacer(20))
	_modal_button(box, "Забрать", UI.GOLD, func() -> void:
		Sfx.play("coin")
		_close_modal())


# --- Contracts --------------------------------------------------------------------

## The purchase agreement: read it, sign it, ask to change it, or walk away.
func _show_contract(c: Dictionary) -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
	var box := _open_modal()
	_modal_text(box, "ДОГОВОР КУПЛИ-ПРОДАЖИ", 32, UI.GOLD, 800)
	_modal_text(box, "%s · %s" % [Data.business(c["biz"])["name"], Data.money(c["price"])], 50, Color.WHITE, 900)
	var scroll: ScrollContainer = TouchScroll.new()
	scroll.custom_minimum_size = Vector2(870, minf(760.0, root.size.y * 0.36))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	box.add_child(scroll)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f4efe2")
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	paper.add_theme_stylebox_override("panel", sb)
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(paper)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 18)
	paper.add_child(lines)
	for clause in c["clauses"]:
		var l := UI.label(clause, 31, Color("#3a3a48"), 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 780
		lines.add_child(l)
	_modal_button(box, "Подписать", UI.GOLD, _sign.bind(c))
	_modal_button(box, "Потребовать убрать пункт", Color("#8f96b8"), _haggle.bind(c))
	var no := UI.flat_button("Отказаться от сделки", 38, UI.SUB, _close_modal)
	box.add_child(no)


func _sign(c: Dictionary) -> void:
	if not s.buy_business(c["biz"], c["price"]):
		Sfx.play("no", -6.0)
		_close_modal()
		return
	var note := Contract.apply(c, s)
	if note == "":
		Sfx.play("up")
		_close_modal()
		_float("Бизнес твой!", Vector2(540, HEADER_H + 230), UI.GOLD, 56)
		_check_rank()
		return
	var good: bool = c["trap"]["kind"] == "bonus"
	_modal.queue_free()
	_modal = null
	var box := _open_modal()
	_modal_text(box, "Сюрприз в договоре" if good else "Надо было читать договор!", 54, GREEN if good else RED, 900)
	_modal_text(box, c["trap"]["text"], 34, Color("#d8dbe8"), 500)
	_modal_text(box, note, 42, Color.WHITE, 800)
	box.add_child(UI.spacer(10))
	_modal_button(box, "Понятно", UI.GOLD, func() -> void:
		_close_modal()
		_check_rank())
	Sfx.play("fanfare" if good else "no", -4.0)


## Asking to strike a clause: right when there is a trap, insulting when not.
func _haggle(c: Dictionary) -> void:
	var bad := Contract.is_bad(c)
	_modal.queue_free()
	_modal = null
	var box := _open_modal()
	if bad and randf() < 0.75:
		var clean := c.duplicate(true)
		clean["clauses"].erase(c["trap"]["text"])
		clean["trap"] = {}
		_modal_text(box, "Продавец покраснел и вычеркнул пункт", 50, GREEN, 900)
		_modal_text(box, "«" + c["trap"]["text"] + "»", 34, Color("#d8dbe8"), 500)
		_modal_text(box, "Ты спас себя от ловушки. Теперь договор чистый.", 40, Color.WHITE, 700)
		_modal_button(box, "Подписать чистый договор", UI.GOLD, _sign.bind(clean))
		_modal_button(box, "Всё равно отказаться", Color("#8f96b8"), _close_modal)
		Sfx.play("fanfare", -4.0)
	elif bad:
		_modal_text(box, "Продавец понял, что ты его раскусил, и ушёл", 50, UI.GOLD, 900)
		_modal_text(box, "Зато ты не попал в ловушку.", 40, Color.WHITE, 700)
		_modal_button(box, "Ладно", UI.GOLD, _close_modal)
	else:
		_modal_text(box, "«Какой ещё пункт?»", 54, Color.WHITE, 900)
		_modal_text(box, "Договор был честным. Продавец обиделся на недоверие и отказался от сделки.", 40, Color("#d8dbe8"), 600)
		_modal_button(box, "Эх", UI.GOLD, _close_modal)
		Sfx.play("no", -4.0)


# --- Effects ----------------------------------------------------------------------

func _float(text: String, at: Vector2, color: Color, size_px: int) -> void:
	var l := UI.label(text, size_px, color, 900)
	UI.glow(l, Color(0, 0, 0, 0.6), 10)
	l.size = Vector2(800, 100)
	l.position = at - l.size * 0.5
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 130, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)
