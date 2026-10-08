extends Node
## ЗОЛОТАЯ ЖИЛА: the mine, the coin counter and boost at the top, the upgrade
## panel, first-steps hints, saving and the coins earned while away.

const Mine := preload("res://scripts/game/mine.gd")
const World := preload("res://scripts/game/world.gd")
const Sheet := preload("res://scripts/game/sheet.gd")
const Eco := preload("res://scripts/game/economy.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Save := preload("res://scripts/save.gd")

const HUD_H := 250.0
const SAVE_EVERY := 3.0

var mine: RefCounted
var root: Control
var world: World
var sheet: Sheet

var _coins: Label
var _income: Label
var _hint: Label
var _boost: Button
var _boost_label: Label
var _hud: Control
var _save_t := 0.0
var _last_unix := 0.0
var _shown := 0.0
var _toggles: Array[Button] = []


func _ready() -> void:
	var dev := OS.get_cmdline_user_args()
	# Developer runs start from a fresh mine and never touch the real save.
	var saved: Dictionary = {} if dev.size() > 0 else Save.get_value("mine", {})
	mine = Mine.from_dict(saved) if not saved.is_empty() else Mine.new()
	_shown = mine.coins
	Sfx.sound_on = Save.get_value("sound", true)
	Sfx.music_on = Save.get_value("music", true)

	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = World.new()
	world.mine = mine
	world.open_station.connect(_open_sheet)
	world.buy_shaft.connect(_buy_shaft)
	world.tapped_nothing.connect(func() -> void:
		if sheet.is_open():
			sheet.close())
	root.add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	sheet = Sheet.new()
	sheet.mine = mine
	sheet.visible = false
	sheet.closed.connect(func() -> void: world.bottom_inset = 0.0)
	root.add_child(sheet)
	sheet.size = Vector2(1080, Sheet.HEIGHT)

	_last_unix = Mine.now()
	if not saved.is_empty():
		_welcome_back(Mine.now() - float(saved.get("saved_at", Mine.now())))

	if dev.size() > 0:
		var tool: Node = load("res://scripts/dev/autoshot.gd").new()
		tool.setup(self, dev)
		add_child(tool)


func _process(delta: float) -> void:
	# A long gap means the page or app was in the background: count it as time away.
	var unix := Mine.now()
	var gap := unix - _last_unix
	_last_unix = unix
	if gap > 10.0:
		_welcome_back(gap)
	mine.tick(minf(delta, 0.25))
	for e in mine.events:
		_on_event(e)
	mine.events.clear()
	_update_hud(delta)
	_save_t += delta
	if _save_t >= SAVE_EVERY:
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	_save_t = 0.0
	if mine and OS.get_cmdline_user_args().is_empty():
		Save.set_value("mine", mine.to_dict())


func _on_event(e: Dictionary) -> void:
	match e["kind"]:
		"deposit":
			var k: int = e["at"]
			var at := Vector2(World.CRATE_X + 52, world.shaft_top(k) + World.TUNNEL_BOTTOM - 110)
			if not mine.shafts[k]["manager"]:
				world.float_text("+" + Eco.short(e["amount"]), at, Eco.ORES[k]["color"].lightened(0.3), 36)
			if _on_screen(at):
				Sfx.play("drop", -12.0)
		"lift":
			Sfx.play("ding", -10.0)
		"sold":
			var at := Vector2(900, world.ground() - 280)
			world.float_text("+" + Eco.short(e["amount"]), at, UI.GOLD, 54)
			world.coin_burst(at + Vector2(0, 40), 8)
			Sfx.play("coin", -4.0)


func _on_screen(content_pos: Vector2) -> bool:
	var y := content_pos.y - world.scroll
	return y > 0.0 and y < root.size.y


# --- HUD ------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud.offset_bottom = HUD_H
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.06, 0.04, 0.14, 0.82)
	_hud.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var coin := Control.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.draw.connect(_draw_coin.bind(coin))
	_hud.add_child(coin)
	coin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_coins = UI.label("0", 96, Color.WHITE, 900)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UI.glow(_coins, Color(1, 0.75, 0.2, 0.45), 18)
	_coins.position = Vector2(150, 40)
	_coins.size = Vector2(560, 110)
	_hud.add_child(_coins)
	_income = UI.label("", 38, Color("#7dffb8"), 700)
	_income.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income.position = Vector2(154, 150)
	_income.size = Vector2(560, 50)
	_hud.add_child(_income)

	# Boost: double income for two minutes, then a rest.
	_boost = Button.new()
	_boost.focus_mode = Control.FOCUS_NONE
	_boost.position = Vector2(890, 34)
	_boost.size = Vector2(150, 150)
	_boost.add_theme_font_override("font", UI.font(900))
	_boost.add_theme_font_size_override("font_size", 54)
	_boost.text = "×2"
	_boost.pressed.connect(func() -> void:
		if mine.start_boost():
			Sfx.play("boost")
		else:
			Sfx.play("no", -6.0))
	_hud.add_child(_boost)
	_boost_label = UI.label("", 28, UI.SUB, 700)
	_boost_label.position = Vector2(860, 186)
	_boost_label.size = Vector2(210, 40)
	_hud.add_child(_boost_label)

	for kind in ["music", "sound"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(92, 92)
		b.position = Vector2(770, 34 if kind == "music" else 136)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08)
		sb.set_corner_radius_all(46)
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
		_hud.add_child(b)
		_toggles.append(b)

	_hint = UI.label("", 38, Color.WHITE, 700)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hb := StyleBoxFlat.new()
	hb.bg_color = Color(0.1, 0.06, 0.2, 0.9)
	hb.set_corner_radius_all(30)
	hb.content_margin_left = 30
	hb.content_margin_right = 30
	hb.content_margin_top = 16
	hb.content_margin_bottom = 16
	hb.border_color = Color(1, 0.83, 0.28, 0.6)
	hb.set_border_width_all(2)
	_hint.add_theme_stylebox_override("normal", hb)
	root.add_child(_hint)


func _update_hud(delta: float) -> void:
	# The counter rolls instead of jumping.
	_shown = lerpf(_shown, mine.coins, 1.0 - exp(-10.0 * delta))
	if absf(_shown - mine.coins) < 1.0 or mine.coins < _shown:
		_shown = mine.coins
	_coins.text = Eco.short(_shown)
	var inc: float = mine.income() * mine.boost_factor()
	_income.text = "+%s в сек" % Eco.short(inc) if inc > 0.0 else ""
	var now := Mine.now()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(75)
	if now < mine.boost_until:
		sb.bg_color = Color("#ff5fa2")
		sb.shadow_color = Color(1, 0.4, 0.7, 0.6)
		sb.shadow_size = 26
		_boost_label.text = "ещё " + _clock(mine.boost_until - now)
	elif now < mine.boost_ready_at:
		sb.bg_color = Color(1, 1, 1, 0.1)
		_boost_label.text = "через " + _clock(mine.boost_ready_at - now)
	else:
		sb.bg_color = Color("#ff5fa2")
		sb.shadow_color = Color(1, 0.4, 0.7, 0.4 + 0.3 * sin(now * 4.0))
		sb.shadow_size = 22
		_boost_label.text = "ускорить"
	for st in ["normal", "hover", "pressed", "focus"]:
		_boost.add_theme_stylebox_override(st, sb)
	_update_hint()


func _clock(seconds: float) -> String:
	var s := int(ceilf(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## First steps, one at a time, until the first manager is hired.
func _update_hint() -> void:
	var text := ""
	var any_manager: bool = mine.lift["manager"] or mine.cart["manager"] or mine.shafts.any(func(s: Dictionary) -> bool: return s["manager"])
	if not any_manager:
		var s0: Dictionary = mine.shafts[0]
		if mine.coins < 1.0 and s0["stock"] <= 0.0 and mine.pile <= 0.0 and mine.lift["load"] <= 0.0 and s0["phase"] == "idle":
			text = "Тапни шахтёра — он накопает угля"
		elif s0["stock"] > 0.0 and mine.lift["phase"] == "idle" and mine.lift["load"] <= 0.0:
			text = "Тапни лифт — он поднимет уголь наверх"
		elif mine.pile > 0.0 and mine.cart["phase"] == "idle":
			text = "Тапни склад — уголь продастся"
		elif mine.coins >= Eco.CART_MANAGER:
			text = "Нажми на «Ур.» у склада и найми управляющего — он будет работать сам"
		elif mine.coins > 0.0 and not sheet.is_open():
			text = "Жми «Ур.» — улучшения ускоряют добычу"
	_hint.text = text
	_hint.visible = text != "" and not sheet.is_open()
	_hint.size = Vector2(960, 0)
	_hint.position = Vector2(60, root.size.y - _hint.get_combined_minimum_size().y - 70)


func _draw_coin(c_item: Control) -> void:
	var c := Vector2(86, 96)
	c_item.draw_circle(c, 44, Color("#e0a815"))
	c_item.draw_circle(c, 36, Color("#ffd447"))
	c_item.draw_arc(c, 26, 0, TAU, 32, Color("#e0a815"), 5, true)
	c_item.draw_circle(c + Vector2(-12, -14), 8, Color(1, 1, 1, 0.6))


func _draw_toggle(b: Button, kind: String) -> void:
	var on: bool = Sfx.sound_on if kind == "sound" else Sfx.music_on
	var col := Color(1, 1, 1, 0.9 if on else 0.35)
	var c := Vector2(46, 46)
	if kind == "sound":
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -8), c + Vector2(-9, -8), c + Vector2(4, -20),
			c + Vector2(4, 20), c + Vector2(-9, 8), c + Vector2(-20, 8)]), col)
		if on:
			b.draw_arc(c + Vector2(4, 0), 12, -0.9, 0.9, 12, col, 4, true)
			b.draw_arc(c + Vector2(4, 0), 21, -0.9, 0.9, 16, col, 4, true)
	else:
		b.draw_line(c + Vector2(-8, 14), c + Vector2(-8, -18), col, 5)
		b.draw_line(c + Vector2(12, 9), c + Vector2(12, -23), col, 5)
		b.draw_line(c + Vector2(-8, -18), c + Vector2(12, -23), col, 7)
		b.draw_circle(c + Vector2(-13, 14), 8, col)
		b.draw_circle(c + Vector2(7, 9), 8, col)
	if not on:
		b.draw_line(c + Vector2(-26, -26), c + Vector2(26, 26), Color(1, 0.4, 0.5, 0.9), 5)


# --- Panel and purchases -----------------------------------------------------------

func _open_sheet(id: String) -> void:
	Sfx.play("click")
	sheet.position = Vector2(0, root.size.y + 40)
	sheet.open(id)
	world.bottom_inset = Sheet.HEIGHT


func _buy_shaft() -> void:
	if mine.open_shaft():
		Sfx.play("fanfare")
		world.reveal_bottom()
		_save()
	else:
		Sfx.play("no", -6.0)


## Coins made while the game was closed or in the background.
func _welcome_back(seconds: float) -> void:
	var earned: float = mine.catch_up(seconds)
	if earned <= 0.0:
		return
	_shown = mine.coins
	var card := Control.new()
	root.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.1, 0.7)
	card.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = root.size.y * 0.3
	box.add_child(UI.label("Пока тебя не было,\nшахта заработала", 52, UI.SUB, 600))
	var amount := UI.label("+" + Eco.short(earned), 150, UI.GOLD, 900)
	UI.glow(amount, Color(1, 0.7, 0.2, 0.7), 26)
	box.add_child(amount)
	box.add_child(UI.spacer(40))
	var take := UI.pill_button("Забрать", UI.GOLD, func() -> void:
		Sfx.play("coin")
		card.queue_free())
	var holder := CenterContainer.new()
	holder.add_child(take)
	box.add_child(holder)
