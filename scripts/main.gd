extends Node
## ОТ НУЛЯ ДО МИЛЛИАРДЕРА: the header with money and status, four tabs (work,
## the city map, your businesses, property), the page for running a business,
## life events with risky choices, hot deals on a timer, new statuses,
## bankruptcy, saving and the days that pass while away.

const State := preload("res://scripts/game/state.gd")
const Data := preload("res://scripts/game/data.gd")
const Events := preload("res://scripts/game/events.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const Save := preload("res://scripts/save.gd")
const TouchScroll := preload("res://scripts/ui/touch_scroll.gd")
const Contract := preload("res://scripts/game/contract.gd")
const Venue := preload("res://scripts/game/venue.gd")
const MapView := preload("res://scripts/ui/map_view.gd")
const VenuePage := preload("res://scripts/ui/venue_page.gd")
const Cars := preload("res://scripts/game/cars.gd")
const Origin := preload("res://scripts/game/origin.gd")
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
const DEAL_GAP := Vector2(120, 200)
const DEAL_TIME := 15.0
## Time away: at most two hours count, up to 60 game days.
const AWAY_CAP := 7200.0

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
var _venue_page: Control
## The current job's mini-game, the cover shown between shifts, and the shift
## clock (seconds left, or 0 when not working).
var _game: Control
var _cover: Control
var _cover_text: Label
var _cover_btn: Button
var _energy: Control
var _shift_left := 0.0
var _shift_earned := 0.0
var _shift_done := false
var _shift_hits := 0
var _shift_fines := 0
## Until when (msec) the start button ignores presses after a shift ends,
## so fast taps on the job cannot start a new shift by accident.
var _cover_lock := 0
var _cover_title: Label
var _cover_amount: Label

var _day_t := 0.0
var _event_t := 25.0
var _deal_t := 90.0
var _save_t := 0.0
var _refresh_t := 0.0
var _shown := 0.0
var _last_event := ""
var _rank_seen := 0
var _last_unix := 0.0
## The screen where a new life picks its start (null when closed).
var _chooser: Control
var _story_t := 0.0


func _ready() -> void:
	var dev := OS.get_cmdline_user_args()
	var saved: Dictionary = {} if dev.size() > 0 else Save.get_value("life3", {})
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
	elif dev.size() == 0:
		_show_origins(false)
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
	if _modal or _chooser or s.bankrupt:
		return
	_day_t += delta
	while _day_t >= Data.DAY:
		_day_t -= Data.DAY
		var change: float = s.next_day()
		if absf(change) >= 1.0:
			_float(("+" if change > 0.0 else "") + Data.money(change), Vector2(540, 250), GREEN if change > 0.0 else RED, 40)
		for line in s.news:
			_float(line, Vector2(540, HEADER_H + 200), RED, 36)
		s.news.clear()
		if _venue_page and is_instance_valid(_venue_page):
			_venue_page.rebuild()
		if s.bankrupt:
			_show_bankrupt()
			return
		_check_rank()
		if s.pending_break != "" and not _modal:
			_show_breakdown()
	# Nothing pops up during a shift: events, deals and the story wait until it ends.
	if not s.on_shift:
		_event_t -= delta
		_story_t -= delta
		if s.crisis >= 0.0:
			_show_crisis()
			return
		if _story_t <= 0.0:
			_story_t = 1.0
			var beat := Origin.next_beat(s)
			if not beat.is_empty():
				_show_beat(beat)
				return
	if _event_t <= 0.0:
		_show_event()
	_tick_deal(delta)
	_tick_shift(delta)
	_save_t += delta
	if _save_t >= 2.0:
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	_save_t = 0.0
	if s and OS.get_cmdline_user_args().is_empty():
		Save.set_value("life3", s.to_dict())
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
	_rank.text = s.rank_name(r)
	_day.text = "День %d" % s.day
	if s.cash < 0.0:
		_flow.text = "ДОЛГ! До банкротства %d дн." % (Data.DEBT_DAYS - s.debt_days)
		_flow.add_theme_color_override("font_color", RED)
	else:
		var p: float = s.last_day["profit"]
		var text := ""
		if s.venues.is_empty():
			text = "Пока нет бизнеса — работай и копи на первый"
		else:
			text = "Вчера: %s%s прибыли" % ["+" if p >= 0.0 else "", Data.money(p)]
		if s.boost() != 1.0:
			text += "   ×%.2f клиентов" % s.boost()
		_flow.text = text
		_flow.add_theme_color_override("font_color", GREEN if p >= 0.0 else Color("#ffb347"))
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
	var items := [["work", "Работа"], ["city", "Город"], ["biz", "Бизнесы"], ["prop", "Имущество"]]
	for i in items.size():
		var id: String = items[i][0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.position = Vector2(i * 270, 0)
		b.size = Vector2(270, TABS_H)
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
	var icon: String = {"work": "coin", "city": "flat", "biz": "bank", "prop": "car"}[id]
	var cx := b.size.x * 0.5
	if on:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.96, 0.77, 0.32, 0.12)
		glow.set_corner_radius_all(40)
		b.draw_style_box(glow, Rect2(20, 18, b.size.x - 40, 150))
	Icons.glyph(b, icon, Vector2(cx, 74), 0.58)
	if not on:
		b.draw_rect(Rect2(cx - 70, 30, 140, 90), Color(0.07, 0.07, 0.11, 0.55))
	var f := UI.font(700)
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	b.draw_string(f, Vector2(cx - w * 0.5, 152), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, col)


func _show_tab(id: String) -> void:
	_close_venue()
	_tab = id
	for k in _pages:
		_pages[k].visible = k == id
	for k in _tab_buttons:
		_tab_buttons[k].queue_redraw()


func _build_pages() -> void:
	for id in ["work", "city", "biz", "prop"]:
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
	_build_city(_pages["city"])
	_build_venues(_pages["biz"])
	_build_props(_pages["prop"])


# --- Work -------------------------------------------------------------------------

func _build_work(page: Control) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 30
	box.offset_right = -30
	box.offset_top = 24
	box.offset_bottom = -20
	var r: Dictionary = Data.RANKS[s.rank()]
	_job = UI.label(r["job"], 48, Color.WHITE, 800)
	box.add_child(_job)
	_pay = UI.label("", 34, GREEN, 700)
	box.add_child(_pay)
	box.add_child(_stats_row())
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(36)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(frame)
	_game = JOBS[r["game"]].new()
	_game.pay = r["pay"] * s.work_mult(r["game"])
	if r["game"] == "negotiation":
		_game.title = "Клиент выбирает франшизу" if s.rank() == 3 else "Клиент решает, нанять ли тебя"
	_game.earned.connect(_on_earned)
	frame.add_child(_game)
	# Between shifts the job is covered by a card: the last shift's result
	# up top, the start button low down, away from where the job is tapped.
	_cover = Control.new()
	frame.add_child(_cover)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.07, 0.86)
	_cover.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_cover.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	col.offset_left = 50
	col.offset_right = -50
	col.offset_top = 70
	_cover_title = UI.label("", 40, UI.SUB, 800)
	col.add_child(_cover_title)
	_cover_amount = UI.label("", 92, GREEN, 900)
	col.add_child(_cover_amount)
	_cover_text = UI.label("", 32, Color("#d8dbe8"), 600)
	_cover_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_cover_text)
	_cover_btn = UI.pill_button("", UI.GOLD, func() -> void:
		if Time.get_ticks_msec() >= _cover_lock:
			_start_shift())
	_cover_btn.add_theme_font_size_override("font_size", 38)
	_cover.add_child(_cover_btn)
	_cover_btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cover_btn.offset_left = 70
	_cover_btn.offset_right = -70
	_cover_btn.offset_top = -170
	_cover_btn.offset_bottom = -56
	var tip_card := PanelContainer.new()
	tip_card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.25)))
	_tip = UI.label("", 32, Color.WHITE, 600)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_card.add_child(_tip)
	box.add_child(tip_card)
	# A shift in progress survives the page being rebuilt (new status, purchases).
	_game.working = _shift_left > 0.0
	_cover.visible = _shift_left <= 0.0
	_refreshers.append(_refresh_work)
	_refresh_work()


func _start_shift() -> void:
	if not s.start_shift():
		Sfx.play("no", -6.0)
		return
	_shift_left = Data.SHIFT_TIME
	_shift_earned = 0.0
	_shift_hits = 0
	_shift_fines = 0
	_shift_done = false
	_game.working = true
	_cover.visible = false
	_refresh_work()


func _tick_shift(delta: float) -> void:
	# The shift clock runs on other tabs too; only a card on screen stops it.
	if _shift_left <= 0.0 or not _game or not is_instance_valid(_game) or UI.modal_open:
		return
	var step := minf(delta, _shift_left)
	_shift_left -= delta
	s.tire(step)
	if _shift_left <= 0.0:
		_shift_left = 0.0
		_shift_done = true
		s.end_shift()
		_game.working = false
		_cover.visible = true
		_cover_lock = Time.get_ticks_msec() + 1500
		_cover_btn.modulate.a = 0.0
		Sfx.play("fanfare", -6.0)
		_refresh_work()
		var tw := _cover_btn.create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(_cover_btn, "modulate:a", 1.0, 0.3)
	_energy.queue_redraw()


## Energy and the trouble of the start, side by side as two small cards.
func _stats_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_energy = Control.new()
	_energy.custom_minimum_size = Vector2(0, 136)
	_energy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy.draw.connect(_draw_energy.bind(_energy))
	row.add_child(_energy)
	var mind := Control.new()
	mind.custom_minimum_size = Vector2(0, 136)
	mind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mind.mouse_filter = Control.MOUSE_FILTER_STOP
	mind.draw.connect(_draw_mind.bind(mind))
	mind.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and not UI.dragging and not _modal and not s.self_healing():
			Sfx.play("click")
			_show_care())
	row.add_child(mind)
	_refreshers.append(mind.queue_redraw)
	return row


func _draw_energy(c: Control) -> void:
	var col := Color("#ffd447") if s.can_work() or _shift_left > 0.0 else Color("#ff9f43")
	var corner := "+%d в день" % int(s.rest())
	if _shift_left > 0.0:
		corner = "ещё %d сек" % ceili(_shift_left)
	_draw_stat(c, "bolt", col, "Энергия", s.energy, corner, Color(1, 1, 1, 0.55), false)


func _draw_mind(c: Control) -> void:
	var o := Origin.info(s.origin)
	var icon: String = {"street": "heart", "family": "home", "rich": "spark"}.get(s.origin, "heart")
	var col: Color = {"heart": Color("#ff5c8a"), "home": Color("#5aa9ff"), "spark": Color("#b388ff")}[icon]
	var corner := "дома +2"
	var corner_col := Color(1, 1, 1, 0.55)
	var pill := false
	var can: bool = s.cash >= s.care_cost() and s.mind < 100.0
	if not s.self_healing():
		corner = "+ " + Data.money(s.care_cost())
		corner_col = Color("#1a1040") if can else Color(1, 1, 1, 0.6)
		pill = true
	var title: String = o.get("meter_short", o["meter"])
	if s.mind < Origin.LOW:
		col = RED
		title += " · отдых ×0,5"
	_draw_stat(c, icon, col, title, s.mind, corner, corner_col, pill, can)


## One stat card: an icon in a soft circle, the name, a big number and a bar.
## `corner` is a small note bottom right, or a price pill to tap for care.
func _draw_stat(c: Control, icon: String, col: Color, title: String, value: float, corner: String, corner_col: Color, pill: bool, can := true) -> void:
	var w := c.size.x
	var h := c.size.y
	var card := StyleBoxFlat.new()
	card.bg_color = CARD
	card.set_corner_radius_all(30)
	card.border_color = Color(col, 0.35)
	card.set_border_width_all(2)
	c.draw_style_box(card, Rect2(0, 0, w, h))
	var ic := Vector2(58, 58)
	c.draw_circle(ic, 38, Color(col, 0.16))
	_draw_glyph(c, icon, ic, col)
	var f := UI.font(700)
	c.draw_string(f, Vector2(110, 42), title, HORIZONTAL_ALIGNMENT_LEFT, w - 120, 24, col if col == RED else UI.SUB)
	var big := UI.font(900)
	var num := str(int(value))
	c.draw_string(big, Vector2(110, 94), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, Color.WHITE)
	var nw := big.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
	c.draw_string(f, Vector2(116 + nw, 94), "/100", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.4))
	if corner != "":
		var cw := f.get_string_size(corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var pos := Vector2(w - 22 - cw, 92)
		if pill:
			var sb := StyleBoxFlat.new()
			sb.bg_color = UI.GOLD if can else Color("#3a3f5c")
			sb.set_corner_radius_all(22)
			c.draw_style_box(sb, Rect2(pos + Vector2(-14, -32), Vector2(cw + 28, 44)))
		c.draw_string(f, pos, corner, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, corner_col)
	var bar := Rect2(24, h - 24, w - 48, 10)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.07)
	back.set_corner_radius_all(5)
	c.draw_style_box(back, bar)
	var k := clampf(value / 100.0, 0.0, 1.0)
	if k > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(5)
		c.draw_style_box(fill, Rect2(bar.position, Vector2(maxf(10.0, bar.size.x * k), bar.size.y)))


func _draw_glyph(c: Control, icon: String, at: Vector2, col: Color) -> void:
	match icon:
		"bolt":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(6, -24), at + Vector2(-14, 4), at + Vector2(-1, 4),
				at + Vector2(-6, 24), at + Vector2(14, -4), at + Vector2(1, -4)]), col)
		"heart":
			c.draw_circle(at + Vector2(-9, -6), 11, col)
			c.draw_circle(at + Vector2(9, -6), 11, col)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-19.5, -2), at + Vector2(19.5, -2), at + Vector2(0, 20)]), col)
		"home":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-22, -2), at + Vector2(0, -22), at + Vector2(22, -2)]), col)
			c.draw_rect(Rect2(at + Vector2(-15, -3), Vector2(30, 23)), col)
			c.draw_rect(Rect2(at + Vector2(-5, 6), Vector2(10, 14)), CARD)
		"spark":
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -24), at + Vector2(6, -6), at + Vector2(24, 0), at + Vector2(6, 6),
				at + Vector2(0, 24), at + Vector2(-6, 6), at + Vector2(-24, 0), at + Vector2(-6, -6)]), col)

func _on_earned(amount: float, at: Vector2, note: String) -> void:
	s.cash += amount
	_shift_earned += amount
	if amount > 0.0:
		_shift_hits += 1
	elif amount < 0.0:
		_shift_fines += 1
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
	var pay: float = Data.RANKS[s.rank()]["pay"]
	if _shift_left > 0.0:
		_pay.text = "За смену: %s%s" % ["+" if _shift_earned >= 0.0 else "", Data.money(_shift_earned)]
	else:
		var game: String = Data.RANKS[s.rank()]["game"]
		var mult: float = s.work_mult(game)
		_pay.text = "%s за удачу · смена %d сек" % [Data.money(pay * mult), int(Data.SHIFT_TIME)]
		if game == "taxi" and not s.has_car():
			_pay.text += " · аренда машины −30%"
		elif mult > 1.0:
			_pay.text += " · транспорт +%d%%" % roundi((mult - 1.0) * 100.0)
	_energy.queue_redraw()
	if _shift_left > 0.0:
		return
	if _shift_done:
		_cover_title.text = "Смена окончена"
		_cover_amount.text = ("+" if _shift_earned >= 0.0 else "") + Data.money(_shift_earned)
		_cover_amount.add_theme_color_override("font_color", GREEN if _shift_earned >= 0.0 else RED)
		var detail := "Удачных: %d" % _shift_hits
		if _shift_fines > 0:
			detail += " · ошибок и штрафов: %d" % _shift_fines
		_cover_text.text = detail + "\nЭнергия: %d / 100" % int(s.energy)
	else:
		_cover_title.text = "Новая смена"
		_cover_amount.text = "%d сек" % int(Data.SHIFT_TIME)
		_cover_amount.add_theme_color_override("font_color", Color.WHITE)
		_cover_text.text = "%s за каждую удачу. Энергия: %d / 100" % [Data.money(pay * s.work_mult(Data.RANKS[s.rank()]["game"])), int(s.energy)]
	var locked := Time.get_ticks_msec() < _cover_lock
	if s.can_work():
		_cover_btn.text = "Выйти на смену  ·  −%d энергии" % int(s.shift_energy())
		if not locked:
			_cover_btn.modulate.a = 1.0
	else:
		var days := ceilf((s.shift_energy() - s.energy) / s.rest())
		_cover_text.text += "\nТы устал: силы вернутся примерно через %d сек. А пока займись бизнесом." % int(days * Data.DAY)
		_cover_btn.text = "Нужно %d энергии" % int(s.shift_energy())
		if not locked:
			_cover_btn.modulate.a = 0.4


## What to do next, in a sentence.
func _advice() -> String:
	if s.cash < 0.0:
		return "Ты в долгах! Работай, сократи расходы или продай что-нибудь — иначе через несколько дней банкротство."
	if s.venues.is_empty():
		if not s.can_work() and s.cash < Data.BUSINESSES[0]["price"] + 8000.0:
			return "Устал — отдохни. Жильё получше восстанавливает силы быстрее (вкладка «Имущество»)."
		if s.cash >= Data.BUSINESSES[0]["price"] + 8000.0:
			return "Хватает на первый бизнес! Открой вкладку «Город», выбери свободное место «S» и открой ларёк с шаурмой."
		return "Выходи на смены и копи %s на первый бизнес (с запасом на продукты и зарплату)." % Data.money(Data.BUSINESSES[0]["price"] + 8000.0)
	for v in s.venues:
		var why := Venue.blocker(v)
		if why != "" and not why.begins_with("Ремонт"):
			return "«%s» не работает: %s. Открой его во вкладке «Бизнесы»." % [Venue.kind(v)["name"], why.to_lower()]
		var r: Dictionary = v["report"]
		if not r.is_empty() and r["lost"] > r["served"] * 0.25:
			return "В «%s» уходят клиенты без покупки — найми ещё сотрудников или закупи больше товара." % Venue.kind(v)["name"]
	if s.owned.is_empty():
		return "Купи жильё или транспорт: статус приводит больше клиентов во все твои бизнесы."
	return "Следи за отчётами: подними цены там, где очереди, сделай ремонт, запусти рекламу, открой точку в районе побогаче."


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


func _list_box(page: Control) -> VBoxContainer:
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
	return box


func _build_props(page: Control) -> void:
	var box := _list_box(page)
	for kind in [["home", "Жильё"], ["ride", "Транспорт"]]:
		var head := UI.label(kind[1], 44, UI.SUB, 800)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 60)
		pad.add_child(head)
		box.add_child(pad)
		for p in Data.PROPERTY:
			if p["kind"] == kind[0]:
				box.add_child(_property_card(p) if kind[0] == "home" else _garage_card(p))
	box.add_child(UI.spacer(30))
	box.add_child(UI.flat_button("Начать новую жизнь", 34, UI.SUB, _ask_new_life))
	box.add_child(UI.spacer(40))


## A vehicle class: the one you own (with its state) or a way to the market.
func _garage_card(p: Dictionary) -> Control:
	var cls: String = p["id"]
	var car: Dictionary = s.garage.get(cls, {})
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.5) if not car.is_empty() else Color(1, 1, 1, 0.06)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	card.add_child(h)
	h.add_child(_icon(cls, Color("#c8921d") if not car.is_empty() else Color("#3a3f5c")))
	if not s.unlocked(p):
		card.modulate = Color(1, 1, 1, 0.6)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var title := UI.label(p["name"] if car.is_empty() else "%s, %d" % [car["model"], car["year"]], 38, Color.WHITE, 800)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(title)
	if not car.is_empty():
		var stars := Control.new()
		stars.custom_minimum_size = Vector2(240, 34)
		stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.draw.connect(func() -> void: Icons.stars(stars, Vector2(0, 17), car["condition"], 5, 14))
		v.add_child(stars)
	var state_text := Cars.perks(cls)
	if not car.is_empty() and car["broken"] > 0:
		state_text = "Сломана: ещё %d дн. без бонусов" % car["broken"]
	var perks := UI.label(state_text, 28, GREEN if car.is_empty() or car["broken"] <= 0 else RED, 600)
	perks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	perks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perks.custom_minimum_size.x = 400
	v.add_child(perks)
	if not car.is_empty():
		h.add_child(_buy_column("", 0.0, p, "Сменить", func() -> void: _show_market(cls)))
	else:
		h.add_child(_buy_column("от", p["price"] * 0.65, p, "Смотреть", func() -> void: _show_market(cls)))
	return _row(card)


## The right side of a property card: the price and a small button — grey when
## the money is not there yet, a lock when the status is not reached.
func _buy_column(prefix: String, price: float, p: Dictionary, label: String, on_press: Callable) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 210
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	if not s.unlocked(p):
		var lock := Control.new()
		lock.custom_minimum_size = Vector2(210, 56)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.draw.connect(func() -> void:
			var c := Vector2(105, 30)
			lock.draw_arc(c + Vector2(0, -6), 13, PI, TAU, 14, UI.SUB, 6, true)
			lock.draw_rect(Rect2(c + Vector2(-19, -6), Vector2(38, 30)), UI.SUB))
		col.add_child(lock)
		col.add_child(UI.label("Откроется:\n«%s»" % Data.RANKS[p["rank"]]["name"], 26, UI.SUB, 700))
		return col
	var pr: Label = null
	if price > 0.0:
		pr = UI.label(("%s " % prefix if prefix != "" else "") + Data.money(price), 30, UI.GOLD, 800)
		pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(pr)
	var btn := UI.pill_button(label, UI.GOLD, on_press)
	btn.custom_minimum_size = Vector2(190, 82)
	btn.add_theme_font_size_override("font_size", 30)
	col.add_child(btn)
	# Grey while the money is not there; it turns gold as soon as it is.
	var paint := func() -> void:
		var can: bool = price <= 0.0 or s.cash >= price
		if pr:
			pr.add_theme_color_override("font_color", UI.GOLD if can else UI.SUB)
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.GOLD if can else Color("#3a3f5c")
		sb.set_corner_radius_all(41)
		for st in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(st, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(k, Color("#1a1040") if can else Color(1, 1, 1, 0.55))
	paint.call()
	_refreshers.append(paint)
	return col


# --- Vehicle market ----------------------------------------------------------------

func _show_market(cls: String) -> void:
	var box := _open_modal()
	_modal_text(box, "АВТОРЫНОК" if cls in ["bike", "oldcar", "car", "sportcar"] else "ПРЕДЛОЖЕНИЯ", 32, UI.GOLD, 800)
	_modal_text(box, Data.property(cls)["name"], 52, Color.WHITE, 900)
	_modal_text(box, Cars.perks(cls), 30, GREEN, 600)
	for car in Cars.offers(cls):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UI.label("%s, %d" % [car["model"], car["year"]], 36, Color.WHITE, 800)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(t)
		var km := "пробег %s км · " % _thousands(car["km"]) if Cars.CLASSES[cls]["km_year"] > 0.0 else ""
		var d := UI.label(km + Data.money(car["price"]), 30, UI.SUB, 600)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(d)
		row.add_child(col)
		var go := UI.pill_button("Смотреть", UI.GOLD, func() -> void: _show_car(car))
		go.custom_minimum_size = Vector2(220, 96)
		go.add_theme_font_size_override("font_size", 34)
		row.add_child(go)
		box.add_child(row)
	box.add_child(UI.spacer(10))
	_modal_button(box, "Закрыть", Color("#8f96b8"), _close_modal)


## The offer window: everything the seller tells you, two checks for what
## he does not, and the purchase.
func _show_car(car: Dictionary) -> void:
	if _modal:
		_modal.queue_free()
		_modal = null
	var cls: String = car["cls"]
	var c: Dictionary = Cars.CLASSES[cls]
	var box := _open_modal()
	_modal_text(box, Data.property(cls)["name"].to_upper(), 30, UI.GOLD, 800)
	_modal_text(box, "%s, %d год" % [car["model"], car["year"]], 52, Color.WHITE, 900)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	box.add_child(stats)
	if c["km_year"] > 0.0:
		_stat(stats, "Пробег", "%s км" % _thousands(car["km"]))
	if c["hp"][1] > 0:
		_stat(stats, "Мощность", "%d л. с." % car["hp"])
	_stat(stats, "Владельцев", str(car["owners"]))
	_stat(stats, "Состояние", ["", "плохое", "так себе", "среднее", "хорошее", "отличное"][car["condition"]])
	var upkeep: float = Data.property(cls)["upkeep"]
	_stat(stats, "Содержание", Data.money(upkeep) + " в день" if upkeep > 0.0 else "бесплатно")
	_stat(stats, "Цена", Data.money(car["price"]))
	_modal_text(box, "Что даёт: " + Cars.perks(cls), 30, GREEN, 600)
	var found := ""
	if car["checked_legal"]:
		var f := Cars.finding(car, true)
		found += (f if f != "" else "Проверка по базе: чисто.") + "\n"
	if car["checked_tech"]:
		var f := Cars.finding(car, false)
		found += (f if f != "" else "Диагностика: всё в порядке.")
	if found != "":
		var bad: bool = (car["checked_legal"] and Cars.finding(car, true) != "") or (car["checked_tech"] and Cars.finding(car, false) != "")
		_modal_text(box, found.strip_edges(), 32, RED if bad else GREEN, 700)
	if c["legal"] and not car["checked_legal"]:
		_modal_button(box, "Проверить по базе · " + Data.money(Cars.check_cost(car, true)), Color("#8f96b8"), _check_car.bind(car, true))
	if c["legal"] and not car["checked_tech"]:
		_modal_button(box, "Диагностика в автосервисе · " + Data.money(Cars.check_cost(car, false)), Color("#8f96b8"), _check_car.bind(car, false))
	var tech_found: bool = car["checked_tech"] and Cars.finding(car, false) != ""
	if tech_found:
		_modal_button(box, "Сторговаться: " + Data.money(car["price"] * 0.7), UI.GOLD, _buy_car.bind(car, car["price"] * 0.7))
	else:
		_modal_button(box, "Купить · " + Data.money(car["price"]), UI.GOLD, _buy_car.bind(car, car["price"]))
	box.add_child(UI.flat_button("Отказаться", 38, UI.SUB, _close_modal))


func _stat(box: VBoxContainer, name: String, value: String) -> void:
	var h := HBoxContainer.new()
	var a := UI.label(name, 34, UI.SUB, 600)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.label(value, 34, Color.WHITE, 800)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	h.add_child(b)
	box.add_child(h)


func _check_car(car: Dictionary, legal: bool) -> void:
	var cost := Cars.check_cost(car, legal)
	if s.cash < cost:
		Sfx.play("no", -6.0)
		return
	s.cash -= cost
	car["checked_legal" if legal else "checked_tech"] = true
	Sfx.play("click")
	_show_car(car)


func _buy_car(car: Dictionary, price: float) -> void:
	if not s.buy_vehicle(car, price):
		Sfx.play("no", -6.0)
		_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)
		return
	var hit := Cars.surprise(car, s)
	_modal.queue_free()
	_modal = null
	if hit.is_empty():
		Sfx.play("fanfare", -2.0)
		_close_modal()
		_float("Теперь у тебя %s!" % car["model"], Vector2(540, HEADER_H + 230), UI.GOLD, 48)
		_check_rank()
		return
	if hit["lost"]:
		s.lose_vehicle(car["cls"])
	var box := _open_modal()
	_modal_text(box, "Надо было проверить!", 56, RED, 900)
	_modal_text(box, hit["text"], 40, Color.WHITE, 700)
	_modal_button(box, "Понятно", UI.GOLD, func() -> void:
		_close_modal()
		_check_rank())
	Sfx.play("no", -2.0)


## A vehicle broke down: pay for repairs, or go without it for a while.
func _show_breakdown() -> void:
	var cls: String = s.pending_break
	s.pending_break = ""
	var car: Dictionary = s.garage.get(cls, {})
	if car.is_empty():
		return
	var cost := roundf(car["price"] * (0.04 + 0.03 * (5 - car["condition"])))
	var box := _open_modal()
	_modal_text(box, "ПОЛОМКА", 32, RED, 800)
	_modal_text(box, "%s сломалась" % car["model"], 56, Color.WHITE, 900)
	_modal_text(box, "Ремонт стоит %s. Если не чинить — 10 дней без её бонусов." % Data.money(cost), 38, Color("#d8dbe8"), 500)
	_modal_button(box, "Починить · " + Data.money(cost), UI.GOLD, func() -> void:
		if s.cash >= cost:
			s.cash -= cost
			Sfx.play("up")
		else:
			car["broken"] = 10
			Sfx.play("no", -4.0)
		_close_modal())
	_modal_button(box, "Пусть стоит", Color("#8f96b8"), func() -> void:
		car["broken"] = 10
		_close_modal())


func _thousands(n: float) -> String:
	var t := str(int(n))
	var out := ""
	while t.length() > 3:
		out = " " + t.right(3) + out
		t = t.left(t.length() - 3)
	return t + out


# --- The city and your businesses ---------------------------------------------------

func _build_city(page: Control) -> void:
	var map: Control = MapView.new()
	map.state = s
	map.plot_tapped.connect(_on_plot)
	page.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.offset_top = 10


func _on_plot(id: int) -> void:
	var v: Dictionary = s.venue_at(id)
	if not v.is_empty():
		_open_venue(v)
		return
	var p: Dictionary = Data.plot(id)
	var d: Dictionary = Data.DISTRICTS[p["d"]]
	var box := _open_modal()
	_modal_text(box, "СВОБОДНОЕ ПОМЕЩЕНИЕ", 32, UI.GOLD, 800)
	_modal_text(box, "%s · %s" % [d["name"], Data.SIZE_NAMES[p["size"]]], 50, Color.WHITE, 900)
	_modal_text(box, "Мимо проходит %d человек в день. Достаток жителей: %d из 5. Аренда %s в день." % [
		int(d["traffic"]), d["wealth"], Data.money(Data.plot_rent(p))], 34, Color("#d8dbe8"), 500)
	var any := false
	for b in Data.BUSINESSES:
		if b["size"] != p["size"]:
			continue
		any = true
		var probe := Venue.make(0, b["id"], id, 0.0)
		var fit: String = ["плохо подходит", "так себе", "хорошо подходит", "отлично подходит"][clampi(int(Venue.fit(probe) * 3.99), 0, 3)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.add_child(_icon(b["id"], b["color"]))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n := UI.label(b["name"], 38, Color.WHITE, 800)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(n)
		var info := UI.label("Оборудование %s · району %s" % [Data.money(b["price"]), fit], 28, UI.SUB, 600)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = 420
		col.add_child(info)
		row.add_child(col)
		var go := UI.pill_button("Открыть", UI.GOLD, func() -> void:
			if s.cash < b["price"]:
				Sfx.play("no", -6.0)
				_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)
				return
			_show_contract(Contract.make(b["id"], b["price"], false, id)))
		go.custom_minimum_size = Vector2(200, 100)
		go.add_theme_font_size_override("font_size", 34)
		row.add_child(go)
		box.add_child(row)
	if not any:
		_modal_text(box, "Здесь пока нечего открыть.", 34, UI.SUB, 600)
	box.add_child(UI.spacer(10))
	_modal_button(box, "Закрыть", Color("#8f96b8"), _close_modal)


func _build_venues(page: Control) -> void:
	var box := _list_box(page)
	if s.venues.is_empty():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.3)))
		var l := UI.label("У тебя пока нет бизнеса. Открой вкладку «Город», выбери свободное помещение и открой своё дело.", 36, Color.WHITE, 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(l)
		box.add_child(_row(card))
		return
	box.add_child(_totals_card())
	for v in s.venues:
		box.add_child(_venue_card(v))
	box.add_child(UI.spacer(40))


## Yesterday across all businesses: revenue, every kind of cost, profit.
func _totals_card() -> Control:
	var t := {"revenue": 0.0, "goods": 0.0, "salaries": 0.0, "rent": 0.0, "power": 0.0, "water": 0.0, "ads": 0.0, "profit": 0.0, "served": 0.0}
	for v in s.venues:
		var r: Dictionary = v["report"]
		for k in t:
			t[k] += r.get(k, 0.0)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.3)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var head := UI.label("Вчера по всем бизнесам", 38, UI.GOLD, 800)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(head)
	_stat(col, "Клиентов", str(int(t["served"])))
	_stat(col, "Выручка", "+" + Data.money(t["revenue"]))
	_stat(col, "Товар", "−" + Data.money(t["goods"]))
	_stat(col, "Зарплаты", "−" + Data.money(t["salaries"]))
	_stat(col, "Аренда", "−" + Data.money(t["rent"]))
	_stat(col, "Свет и вода", "−" + Data.money(t["power"] + t["water"]))
	if t["ads"] > 0.0:
		_stat(col, "Реклама", "−" + Data.money(t["ads"]))
	var p: float = t["profit"]
	var line := HBoxContainer.new()
	var a := UI.label("Прибыль", 40, Color.WHITE, 900)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.label(("+" if p >= 0.0 else "") + Data.money(p), 40, GREEN if p >= 0.0 else RED, 900)
	line.add_child(a)
	line.add_child(b)
	col.add_child(line)
	return _row(card)


func _venue_card(v: Dictionary) -> Control:
	var b := Venue.kind(v)
	var card := PanelContainer.new()
	var why := Venue.blocker(v)
	card.add_theme_stylebox_override("panel", _card_box(RED if why != "" and not why.begins_with("Ремонт") else Color(1, 1, 1, 0.06)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	card.add_child(h)
	h.add_child(_icon(b["id"], b["color"]))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	h.add_child(col)
	var n := UI.label(b["name"], 40, Color.WHITE, 800)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(n)
	var where := UI.label(Venue.district(v)["name"], 30, UI.SUB, 600)
	where.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(where)
	var stars := Control.new()
	stars.custom_minimum_size = Vector2(240, 36)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.draw.connect(func() -> void: Icons.stars(stars, Vector2(0, 18), v["rating"], 5, 15))
	col.add_child(stars)
	var r: Dictionary = v["report"]
	var line := UI.label("", 32, GREEN, 700)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 520
	if why != "":
		line.text = why
		line.add_theme_color_override("font_color", RED if not why.begins_with("Ремонт") else Color("#ffb347"))
	elif not r.is_empty():
		var p: float = r["profit"]
		line.text = "Вчера %s%s · %d %s" % ["+" if p >= 0.0 else "", Data.money(p), int(r["served"]), b["client"]]
		line.add_theme_color_override("font_color", GREEN if p >= 0.0 else RED)
	else:
		line.text = "Готов к работе"
	col.add_child(line)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	card.add_child(tap)
	tap.pressed.connect(UI.guarded(func() -> void:
		Sfx.play("click")
		_open_venue(v)))
	return _row(card)


func _open_venue(v: Dictionary) -> void:
	_close_venue()
	_venue_page = VenuePage.new()
	_venue_page.state = s
	_venue_page.v = v
	_venue_page.closed.connect(_close_venue)
	_venue_page.changed.connect(func() -> void:
		_rebuild_pages()
		_check_rank())
	root.add_child(_venue_page)
	_venue_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_venue_page.offset_top = HEADER_H
	_venue_page.offset_bottom = -TABS_H
	root.move_child(_deal_box, -1)


func _close_venue() -> void:
	if _venue_page and is_instance_valid(_venue_page):
		_venue_page.queue_free()
	_venue_page = null


func _row(card_child: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 40)
	m.add_theme_constant_override("margin_right", 40)
	m.add_child(card_child)
	return m


func _property_card(p: Dictionary) -> Control:
	var id: String = p["id"]
	var card := PanelContainer.new()
	var has: bool = s.owned.has(id)
	card.add_theme_stylebox_override("panel", _card_box(Color(0.96, 0.77, 0.32, 0.5) if has else Color(1, 1, 1, 0.06)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	card.add_child(h)
	h.add_child(_icon(id, Color("#3a3f5c") if not has else Color("#c8921d")))
	if not s.unlocked(p):
		card.modulate = Color(1, 1, 1, 0.6)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name := UI.label(p["name"], 40, Color.WHITE, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	var perks := UI.label("Статус: клиентов +%d%%" % roundi(p["prestige"] * 100.0), 32, GREEN, 700)
	perks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(perks)
	var cost_text: String = "Содержание: %s в день" % Data.money(p["upkeep"]) if p["upkeep"] > 0.0 else "Без расходов"
	if p.get("rest", 0.0) > 0.0:
		cost_text += " · отдых +%d энергии" % int(p["rest"])
	var cost := UI.label(cost_text, 30, UI.SUB, 600)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.custom_minimum_size.x = 400
	v.add_child(cost)
	if has:
		var mine := UI.label("Твоё", 40, UI.GOLD, 900)
		mine.custom_minimum_size = Vector2(210, 0)
		h.add_child(mine)
	else:
		h.add_child(_buy_column("", p["price"], p, "Смотреть", func() -> void: _show_home(p, p["price"])))
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
	# Above the tab bar, where it covers the least of what you are doing.
	_deal_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_deal_box.offset_left = 40
	_deal_box.offset_right = -40
	_deal_box.offset_top = -TABS_H - 196
	_deal_box.offset_bottom = -TABS_H - 26
	_deal_box.draw.connect(_draw_deal)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_deal_box.add_child(b)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.pressed.connect(UI.guarded(_take_deal))


func _tick_deal(delta: float) -> void:
	_deal_box.visible = not _deal.is_empty() and not s.on_shift
	if s.on_shift:
		return
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
	var budget := maxf(60000.0, s.cash * 2.5)
	for b in Data.BUSINESSES:
		if b["price"] * 1.3 > budget:
			continue
		var free := Data.PLOTS.filter(func(p: Dictionary) -> bool: return p["size"] == b["size"] and s.venue_at(p["id"]).is_empty())
		if not free.is_empty():
			var p: Dictionary = free[randi() % free.size()]
			offers.append({"kind": "biz", "item": b, "plot": p["id"]})
	for p in Data.PROPERTY:
		if not s.owned.has(p["id"]) and p["price"] <= budget and s.unlocked(p):
			offers.append({"kind": "prop", "item": p})
	if offers.is_empty():
		return
	_deal = offers[randi() % offers.size()]
	_deal["off"] = randf_range(0.35, 0.6)
	# A ready business comes renovated, staffed and stocked.
	var base: float = _deal["item"]["price"] * (1.3 if _deal["kind"] == "biz" else 1.0)
	_deal["price"] = roundf(base * (1.0 - _deal["off"]))
	_deal["left"] = DEAL_TIME
	_deal_box.visible = true
	Sfx.play("ding", -4.0)


func _draw_deal() -> void:
	if _deal.is_empty():
		return
	var r := Rect2(Vector2.ZERO, _deal_box.size)
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1d1426")
	sb.set_corner_radius_all(40)
	sb.border_color = Color("#ff5fa2").lerp(UI.GOLD, glow * 0.6)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(1, 0.37, 0.64, 0.25 + 0.2 * glow)
	sb.shadow_size = 26
	_deal_box.draw_style_box(sb, r)
	var item: Dictionary = _deal["item"]
	Icons.tile(_deal_box, item["id"], Rect2(24, 24, 122, 122), item.get("color", Color("#c8921d")))
	var f := UI.font(800)
	# The discount on a pink chip.
	var chip := "−%d%%" % roundi(_deal["off"] * 100.0)
	var cw := f.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 30
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color("#ff5fa2")
	csb.set_corner_radius_all(18)
	_deal_box.draw_style_box(csb, Rect2(170, 22, cw, 40))
	_deal_box.draw_string(f, Vector2(185, 52), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	_deal_box.draw_string(f, Vector2(170 + cw + 14, 52), "ГОРЯЩАЯ СДЕЛКА", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ff9cc6"))
	var what: String = item["name"]
	if _deal["kind"] == "biz":
		what = "%s · %s" % [item["name"], Data.DISTRICTS[Data.plot(_deal["plot"])["d"]]["name"]]
	_deal_box.draw_string(f, Vector2(170, 104), what, HORIZONTAL_ALIGNMENT_LEFT, 640, 34, Color.WHITE)
	# Old price struck through, new price in gold.
	var base: float = item["price"] * (1.3 if _deal["kind"] == "biz" else 1.0)
	var old := Data.money(base)
	var ow := f.get_string_size(old, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_deal_box.draw_string(f, Vector2(170, 146), old, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.SUB)
	_deal_box.draw_line(Vector2(168, 137), Vector2(172 + ow, 137), UI.SUB, 3)
	_deal_box.draw_string(f, Vector2(186 + ow, 148), Data.money(_deal["price"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UI.GOLD)
	# The time left as a ring.
	var c := Vector2(r.size.x - 70, r.size.y * 0.5)
	var k: float = _deal["left"] / DEAL_TIME
	_deal_box.draw_arc(c, 40, 0, TAU, 40, Color(1, 1, 1, 0.1), 8, true)
	_deal_box.draw_arc(c, 40, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color("#ff5fa2"), 8, true)
	var sec := str(ceili(_deal["left"]))
	var sw := f.get_string_size(sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	_deal_box.draw_string(f, c + Vector2(-sw * 0.5, 12), sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)


func _take_deal() -> void:
	if _deal.is_empty():
		return
	if _deal["kind"] == "biz":
		# Hot deals come with contracts too, and cheap ones hide traps more often.
		if s.cash >= _deal["price"]:
			var c := Contract.make(_deal["item"]["id"], _deal["price"], true, _deal["plot"], true)
			_deal = {}
			_deal_box.visible = false
			_show_contract(c)
		else:
			Sfx.play("no", -6.0)
			_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)
		return
	var item: Dictionary = _deal["item"]
	var price: float = _deal["price"]
	_deal = {}
	_deal_box.visible = false
	if item["kind"] == "ride":
		# A cheap vehicle on a timer: look closely, sellers in a hurry hide things.
		var car := Cars.make(item["id"], true)
		car["price"] = price
		_show_car(car)
	else:
		_show_home(item, price)


func _show_home(p: Dictionary, price: float) -> void:
	var box := _open_modal()
	_modal_text(box, "ЖИЛЬЁ", 32, UI.GOLD, 800)
	_modal_text(box, p["name"], 54, Color.WHITE, 900)
	var stats := VBoxContainer.new()
	box.add_child(stats)
	_stat(stats, "Цена", Data.money(price))
	_stat(stats, "Содержание", Data.money(p["upkeep"]) + " в день")
	_stat(stats, "Отдых", "+%d энергии в день" % int(p.get("rest", 0.0)))
	_stat(stats, "Статус", "клиентов +%d%%" % roundi(p["prestige"] * 100.0))
	_modal_button(box, "Купить · " + Data.money(price), UI.GOLD, func() -> void:
		if s.buy_property(p["id"], price):
			Sfx.play("fanfare", -2.0)
			_close_modal()
			_check_rank()
		else:
			Sfx.play("no", -6.0)
			_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46))
	box.add_child(UI.flat_button("Отказаться", 38, UI.SUB, _close_modal))


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
	var v: Dictionary = s.venue(e.get("biz_id", -1))
	if not v.is_empty():
		biz = Venue.kind(v)["name"]
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
		_close_modal()
		_show_origins(false))


## The days that passed while the game was closed are played out for real,
## then reported business by business: who earned, who lost and why.
func _welcome_back(seconds: float) -> void:
	if _modal:
		return
	var days := mini(int(minf(seconds, AWAY_CAP) / Data.DAY), 60)
	if days < 3:
		return
	var stats := {}
	for v in s.venues:
		stats[v["id"]] = {"v": v, "profit": 0.0, "revenue": 0.0, "served": 0.0, "lost": 0.0, "idle": 0, "why": ""}
	var before: float = s.cash
	var energy_before: float = s.energy
	var upkeep := 0.0
	var passed := 0
	s.away = true
	for i in days:
		upkeep += s.upkeep()
		s.next_day()
		passed += 1
		for v in s.venues:
			if not stats.has(v["id"]):
				continue
			var st: Dictionary = stats[v["id"]]
			var r: Dictionary = v["report"]
			st["profit"] += r["profit"]
			st["revenue"] += r["revenue"]
			st["served"] += r["served"]
			st["lost"] += r["lost"]
			if r["why"] != "":
				st["idle"] += 1
				st["why"] = r["why"]
		# No bankruptcy while away: debts wait for the player to come back.
		s.debt_days = 0
	s.away = false
	s.news.clear()
	var earned: float = s.cash - before
	_shown = s.cash
	if stats.is_empty():
		return
	var box := _open_modal()
	_modal_text(box, "С возвращением!", 58, Color.WHITE, 900)
	var hours := seconds / 3600.0
	var away := "%d ч" % int(hours) if hours >= 1.0 else "%d мин" % int(seconds / 60.0)
	_modal_text(box, "Тебя не было %s — в игре прошло %d дн." % [away, passed], 34, UI.SUB, 600)
	var total := _modal_text(box, ("+" if earned >= 0.0 else "") + Data.money(earned), 96, GREEN if earned >= 0.0 else RED, 900)
	UI.glow(total, Color(GREEN if earned >= 0.0 else RED, 0.45), 18)
	if not stats.is_empty():
		var scroll: ScrollContainer = TouchScroll.new()
		scroll.custom_minimum_size = Vector2(870, minf(130.0 * stats.size() + 20.0, root.size.y * 0.34))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		box.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 14)
		scroll.add_child(list)
		var rows := stats.values()
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["profit"] > b["profit"])
		for st in rows:
			list.add_child(_away_row(st, passed))
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 4)
	box.add_child(summary)
	if upkeep > 0.0:
		_stat(summary, "Жильё и транспорт", "−" + Data.money(upkeep))
	_stat(summary, "Энергия", "%d → %d" % [int(energy_before), int(s.energy)])
	box.add_child(UI.spacer(10))
	if s.cash < 0.0:
		_modal_text(box, "Ты в долгах! Есть %d дн., чтобы выйти в плюс." % (Data.DEBT_DAYS - s.debt_days), 32, RED, 800)
	_modal_button(box, "Понятно", UI.GOLD, func() -> void:
		Sfx.play("coin")
		_close_modal())


## One business in the away report: what it earned and what went wrong.
func _away_row(st: Dictionary, days: int) -> Control:
	var v: Dictionary = st["v"]
	var b := Venue.kind(v)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 20
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	card.add_child(h)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(90, 90)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: Icons.tile(icon, b["id"], Rect2(Vector2.ZERO, icon.size), b["color"]))
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var name := UI.label("%s · %s" % [b["name"], Venue.district(v)["name"]], 27, Color.WHITE, 800)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.clip_text = true
	name.custom_minimum_size.x = 440
	col.add_child(name)
	var line := "обслужено %d %s" % [int(st["served"]), b["client"]]
	if st["lost"] >= 1.0:
		line += " · ушли %d" % int(st["lost"])
	var info := UI.label(line, 26, UI.SUB, 600)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(info)
	if st["idle"] > 0:
		var why: String = st["why"]
		var hint := ""
		if why.begins_with("Склад"):
			hint = " — найми управляющего, он закупает сам"
		var idle := UI.label("простой %d из %d дн.: %s%s" % [st["idle"], days, why.get_slice(" — ", 0).to_lower(), hint], 24, Color("#ffb347"), 600)
		idle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		idle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		idle.custom_minimum_size.x = 440
		col.add_child(idle)
	var p: float = st["profit"]
	var money := UI.label(("+" if p >= 0.0 else "") + Data.money(p), 32, GREEN if p >= 0.0 else RED, 900)
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(money)
	return card


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
	var v: Dictionary = s.open_venue(c["biz"], c["plot"], c["price"], c["ready"])
	if v.is_empty():
		Sfx.play("no", -6.0)
		_close_modal()
		return
	var note := Contract.apply(c, s, v)
	if note == "":
		Sfx.play("up")
		_close_modal()
		_check_rank()
		_open_venue(v)
		_float("Бизнес твой! Найми людей и закупи товар", Vector2(540, HEADER_H + 230), UI.GOLD, 44)
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
		_check_rank()
		_open_venue(v))
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


# --- The start, its trouble and its story ---------------------------------------------

## What the trouble meter means and the care that helps, in a card.
func _show_care() -> void:
	var o := Origin.info(s.origin)
	var cost: float = s.care_cost()
	var box := _open_modal()
	_modal_text(box, o["meter"].to_upper() + "  ·  %d / 100" % int(s.mind), 30, UI.GOLD, 800)
	_modal_text(box, o["care"], 62, Color.WHITE, 900)
	_modal_text(box, o["care_text"], 38, Color("#d8dbe8"), 500)
	_modal_text(box, "+%d. Ниже %d отдых вдвое хуже, на нуле — «%s»." % [int(o["care_gain"]), int(Origin.LOW), o["crisis"]], 32, UI.SUB, 600)
	box.add_child(UI.spacer(10))
	_modal_button(box, "Оплатить · %s" % Data.money(cost), UI.GOLD if s.cash >= cost and s.mind < 100.0 else Color("#8f96b8"), func() -> void:
		_close_modal()
		_care())
	box.add_child(UI.flat_button("Позже", 38, UI.SUB, _close_modal))

func _care() -> void:
	var o := Origin.info(s.origin)
	if s.mind >= 100.0:
		_float("%s и так в порядке" % o["meter"], Vector2(540, HEADER_H + 230), UI.SUB, 40)
		return
	var before: float = s.mind
	if not s.care():
		Sfx.play("no", -6.0)
		_float("Не хватает денег", Vector2(540, HEADER_H + 230), RED, 46)
		return
	Sfx.play("coin", -4.0)
	_float("%s +%d" % [o["meter"], roundi(s.mind - before)], Vector2(540, HEADER_H + 230), GREEN, 46)


func _show_beat(beat: Dictionary) -> void:
	s.story[beat["id"]] = true
	if beat.get("calm", false):
		s.calm = true
	Sfx.play("ding")
	var box := _open_modal()
	_modal_text(box, "ИСТОРИЯ  ·  %s" % Origin.info(s.origin)["name"].to_upper(), 30, UI.GOLD, 800)
	_modal_text(box, beat["title"], 62, Color.WHITE, 900)
	_modal_text(box, beat["text"], 38, Color("#d8dbe8"), 500)
	box.add_child(UI.spacer(16))
	_modal_button(box, "Дальше", UI.GOLD, _close_modal)


## The meter hit zero: what it cost and what it means.
func _show_crisis() -> void:
	var o := Origin.info(s.origin)
	var lost: float = s.crisis
	s.crisis = -1.0
	Sfx.play("no")
	var box := _open_modal()
	_modal_text(box, o["meter"].to_upper() + " НА НУЛЕ", 32, RED, 800)
	_modal_text(box, o["crisis"], 72, Color.WHITE, 900)
	_modal_text(box, o["crisis_text"], 38, Color("#d8dbe8"), 500)
	if lost >= 1.0:
		var l := _modal_text(box, "−" + Data.money(lost), 90, RED, 900)
		UI.glow(l, Color(RED, 0.45), 18)
	_modal_text(box, "Силы на нуле. Не доводи до этого: «%s» стоит куда дешевле." % o["care"], 34, UI.SUB, 600)
	box.add_child(UI.spacer(16))
	_modal_button(box, "Тяжело, но дальше", UI.GOLD, _close_modal)


func _ask_new_life() -> void:
	var box := _open_modal()
	_modal_text(box, "Новая жизнь?", 62, Color.WHITE, 900)
	_modal_text(box, "Ты выберешь, с кого начать. Всё, что есть сейчас — деньги, бизнесы, имущество, — пропадёт.", 38, Color("#d8dbe8"), 500)
	box.add_child(UI.spacer(16))
	_modal_button(box, "Начать заново", RED, func() -> void:
		_close_modal()
		_show_origins(true))
	box.add_child(UI.flat_button("Остаться", 38, UI.SUB, _close_modal))


## The screen with the three starts. `can_back` lets the player return to his life.
func _show_origins(can_back: bool) -> void:
	_chooser = Control.new()
	root.add_child(_chooser)
	_chooser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	_chooser.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 28)
	_chooser.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 44
	col.offset_right = -44
	var title := UI.label("Кем ты начнёшь?", 72, Color.WHITE, 900)
	UI.glow(title, Color(0.96, 0.77, 0.32, 0.35), 20)
	col.add_child(title)
	var sub := UI.label("У каждого старта свои деньги, своя трудность и своя история", 32, UI.SUB, 600)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	col.add_child(UI.spacer(10))
	for id in Origin.ORIGINS:
		col.add_child(_origin_card(id))
	if can_back:
		col.add_child(UI.flat_button("Вернуться к своей игре", 36, UI.SUB, func() -> void:
			_chooser.queue_free()
			_chooser = null))
	_chooser.modulate.a = 0.0
	_chooser.create_tween().tween_property(_chooser, "modulate:a", 1.0, 0.35)


func _origin_card(id: String) -> Control:
	var o := Origin.info(id)
	var card := PanelContainer.new()
	var sb := _card_box(Color(o["color"], 0.7))
	sb.content_margin_left = 26
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and not _modal:
			Sfx.play("click")
			_pick_origin(id))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(_draw_origin.bind(icon, id))
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name := UI.label(o["name"], 40, Color.WHITE, 900)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	var chip := PanelContainer.new()
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(o["tag_color"], 0.18)
	csb.set_corner_radius_all(20)
	csb.content_margin_left = 16
	csb.content_margin_right = 16
	csb.content_margin_top = 4
	csb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", csb)
	chip.add_child(UI.label(o["tag"], 24, o["tag_color"], 800))
	top.add_child(chip)
	for line in [[o["about"], Color("#d8dbe8")], ["+ " + o["plus"], GREEN], ["− " + o["minus"], Color("#ff8a8a")]]:
		var l := UI.label(line[0], 28, line[1], 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		v.add_child(l)
	return card


## A small picture for each start: a bench under the moon, a home, a diamond.
func _draw_origin(c: Control, id: String) -> void:
	var o := Origin.info(id)
	var mid := c.size * 0.5
	c.draw_circle(mid, 72, Color(o["color"], 0.25))
	c.draw_circle(mid, 72, Color(o["color"], 0.6), false, 3.0, true)
	match id:
		"street":
			c.draw_circle(mid + Vector2(22, -28), 18, Color("#ffe9a8"))
			c.draw_circle(mid + Vector2(31, -34), 16, Color(o["color"], 1.0).darkened(0.55).lerp(BG, 0.4))
			c.draw_rect(Rect2(mid + Vector2(-44, 8), Vector2(88, 12)), Color("#c79a62"))
			c.draw_rect(Rect2(mid + Vector2(-44, -12), Vector2(88, 10)), Color("#c79a62"))
			c.draw_rect(Rect2(mid + Vector2(-38, 20), Vector2(8, 22)), Color("#7a5a3a"))
			c.draw_rect(Rect2(mid + Vector2(30, 20), Vector2(8, 22)), Color("#7a5a3a"))
		"family":
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-50, -4), mid + Vector2(0, -46), mid + Vector2(50, -4)]), Color("#e86a5a"))
			c.draw_rect(Rect2(mid + Vector2(-38, -6), Vector2(76, 50)), Color("#f2e6d0"))
			c.draw_rect(Rect2(mid + Vector2(-26, 6), Vector2(22, 20)), Color("#ffd447"))
			c.draw_rect(Rect2(mid + Vector2(8, 10), Vector2(18, 34)), Color("#7a5a3a"))
		"rich":
			var pts := PackedVector2Array([mid + Vector2(-44, -14), mid + Vector2(-24, -38), mid + Vector2(24, -38), mid + Vector2(44, -14), mid + Vector2(0, 44)])
			c.draw_colored_polygon(pts, Color("#9fe3ff"))
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-44, -14), mid + Vector2(44, -14), mid + Vector2(0, 44)]), Color("#6cc4f0"))
			c.draw_line(mid + Vector2(-24, -38), mid + Vector2(-12, -14), Color(1, 1, 1, 0.7), 3.0, true)
			c.draw_line(mid + Vector2(24, -38), mid + Vector2(12, -14), Color(1, 1, 1, 0.7), 3.0, true)
			c.draw_line(mid + Vector2(-12, -14), mid + Vector2(0, 44), Color(1, 1, 1, 0.5), 3.0, true)
			c.draw_line(mid + Vector2(12, -14), mid + Vector2(0, 44), Color(1, 1, 1, 0.5), 3.0, true)


## A start was tapped: its opening story, then the choice is confirmed.
func _pick_origin(id: String) -> void:
	var o := Origin.info(id)
	var intro: Dictionary = Origin.BEATS[id][0]
	var box := _open_modal()
	_modal_text(box, o["name"].to_upper(), 30, UI.GOLD, 800)
	_modal_text(box, intro["title"], 62, Color.WHITE, 900)
	_modal_text(box, intro["text"], 38, Color("#d8dbe8"), 500)
	_modal_text(box, "Старт: %s" % Data.money(o["cash"]), 40, GREEN, 800)
	box.add_child(UI.spacer(10))
	_modal_button(box, "Начать", UI.GOLD, func() -> void:
		_new_life(id)
		_close_modal())
	box.add_child(UI.flat_button("Выбрать другой", 36, UI.SUB, func() -> void:
		if _modal:
			_modal.queue_free()
		_modal = null
		UI.modal_open = false))


func _new_life(id: String) -> void:
	s = State.new()
	s.setup(id)
	s.story[Origin.BEATS[id][0]["id"]] = true
	_close_venue()
	_shift_left = 0.0
	_shift_earned = 0.0
	_shift_done = false
	_shown = s.cash
	_rank_seen = s.rank()
	_deal = {}
	_deal_box.visible = false
	_event_t = 25.0
	_deal_t = 90.0
	_story_t = 4.0
	if _chooser:
		_chooser.queue_free()
	_chooser = null
	_save()
	_rebuild_pages()
	_show_tab("work")
