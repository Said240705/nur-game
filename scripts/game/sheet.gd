extends Control
## The upgrade panel that slides up from the bottom for one station:
## what the next levels give, the price, ×1 / ×10 / max, and hiring a manager.

signal closed

const Eco := preload("res://scripts/game/economy.gd")
const UI := preload("res://scripts/ui/ui.gd")
const HEIGHT := 900.0

var mine: RefCounted
var id := ""

var _mult := 1
var _title: Label
var _level: Label
var _rows: Array[Array] = []
var _buy: Button
var _hire: Button
var _hire_note: Label
var _mult_buttons: Array[Button] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1a1230")
	sb.corner_radius_top_left = 50
	sb.corner_radius_top_right = 50
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.border_width_top = 2
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 40
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var close := UI.flat_button("×", 72, UI.SUB, _close)
	close.position = Vector2(950, 20)
	close.size = Vector2(110, 110)
	add_child(close)

	var box := VBoxContainer.new()
	box.position = Vector2(60, 40)
	box.size = Vector2(960, HEIGHT - 60)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = UI.label("", 56, UI.TEXT, 800)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_title)
	_level = UI.label("", 40, UI.GOLD, 700)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_level)
	box.add_child(UI.spacer(10))
	for i in 2:
		var row := HBoxContainer.new()
		var name := UI.label("", 40, UI.SUB, 500)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := UI.label("", 42, UI.TEXT, 700)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(name)
		row.add_child(value)
		box.add_child(row)
		_rows.append([name, value])
	box.add_child(UI.spacer(16))
	var mults := HBoxContainer.new()
	mults.add_theme_constant_override("separation", 16)
	mults.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in [1, 10, 0]:
		var b := UI.flat_button("МАКС" if m == 0 else "×%d" % m, 40, UI.TEXT, func() -> void:
			_mult = m
			_refresh_mults())
		b.custom_minimum_size = Vector2(200, 84)
		mults.add_child(b)
		_mult_buttons.append(b)
	box.add_child(mults)
	box.add_child(UI.spacer(6))
	_buy = UI.pill_button("", UI.GOLD, _upgrade)
	_buy.custom_minimum_size = Vector2(960, 140)
	box.add_child(_buy)
	box.add_child(UI.spacer(6))
	_hire = UI.pill_button("", Color("#2ee59d"), _hire_manager)
	_hire.custom_minimum_size = Vector2(960, 120)
	_hire.add_theme_font_size_override("font_size", 44)
	box.add_child(_hire)
	_hire_note = UI.label("Управляющий работает сам — даже когда игра закрыта", 32, UI.SUB, 500)
	box.add_child(_hire_note)
	_refresh_mults()


func open(station: String) -> void:
	id = station
	_mult = 1
	_refresh_mults()
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", get_viewport_rect().size.y - HEIGHT, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	_close()


func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", get_viewport_rect().size.y + 40, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		hide()
		id = "")
	closed.emit()


func is_open() -> bool:
	return visible and id != ""


func _refresh_mults() -> void:
	for i in _mult_buttons.size():
		var on: bool = [1, 10, 0][i] == _mult
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.16 if on else 0.05)
		sb.set_corner_radius_all(42)
		for st in ["normal", "hover", "pressed", "focus"]:
			_mult_buttons[i].add_theme_stylebox_override(st, sb)


func _count() -> int:
	if _mult == 0:
		return maxi(1, mine.affordable(id))
	return _mult


func _upgrade() -> void:
	if mine.upgrade(id, _count()):
		Sfx.play("up")
	else:
		Sfx.play("no", -6.0)


func _hire_manager() -> void:
	if mine.hire(id):
		Sfx.play("fanfare", -4.0)
	else:
		Sfx.play("no", -6.0)


func _process(_delta: float) -> void:
	if not visible or id == "":
		return
	var n := _count()
	var l: int = mine.level(id)
	var nl := l + n
	if id.begins_with("shaft:"):
		var i := int(id.get_slice(":", 1))
		_title.text = "Шахта %d · %s" % [i + 1, Eco.ORES[i]["name"]]
		_set_row(0, "Добыча за раз", Eco.short(Eco.shaft_output(i, l)), Eco.short(Eco.shaft_output(i, nl)))
		_set_row(1, "В секунду", Eco.short(Eco.shaft_output(i, l) / Eco.shaft_cycle()), Eco.short(Eco.shaft_output(i, nl) / Eco.shaft_cycle()))
	elif id == "lift":
		_title.text = "Лифт"
		_set_row(0, "Вместимость", Eco.short(Eco.lift_capacity(l)), Eco.short(Eco.lift_capacity(nl)))
		_set_row(1, "Скорость", "%.1f" % Eco.lift_speed(l), "%.1f" % Eco.lift_speed(nl))
	else:
		_title.text = "Склад"
		_set_row(0, "Уносит за раз", Eco.short(Eco.cart_capacity(l)), Eco.short(Eco.cart_capacity(nl)))
		_set_row(1, "Ходка, сек", "%.1f" % (Eco.cart_walk(l) * 2.0), "%.1f" % (Eco.cart_walk(nl) * 2.0))
	var milestone := Eco.MILESTONE - l % Eco.MILESTONE
	_level.text = "Уровень %d   ·   ×2 через %d ур." % [l, milestone]
	var price: float = mine.cost(id, n)
	_buy.text = "Улучшить ×%d  ·  %s" % [n, Eco.short(price)]
	_buy.modulate.a = 1.0 if price <= mine.coins else 0.45
	var has: bool = mine.has_manager(id)
	_hire.visible = not has
	_hire_note.text = "Управляющий нанят: работает сам" if has else "Управляющий работает сам — даже когда игра закрыта"
	if not has:
		var mc: float = mine.manager_cost(id)
		_hire.text = "Нанять управляющего  ·  %s" % Eco.short(mc)
		_hire.modulate.a = 1.0 if mc <= mine.coins else 0.45


func _set_row(i: int, name: String, now: String, next: String) -> void:
	_rows[i][0].text = name
	_rows[i][1].text = now + "  →  " + next
	_rows[i][1].add_theme_color_override("font_color", Color("#7dffb8"))
