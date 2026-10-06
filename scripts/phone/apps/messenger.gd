extends Control
## The messenger: deep-blue chat list with search and pinned chats; inside a chat,
## a patterned wallpaper, tailed bubbles with read ticks, "last seen" status and
## an input bar the detective cannot type into.

const UI := preload("res://scripts/phone/ui.gd")
const BG := Color(0.055, 0.075, 0.11)
const BAR := Color(0.085, 0.11, 0.16)
const BLUE := Color(0.36, 0.62, 0.98)
const MINE := Color(0.2, 0.42, 0.74)
const THEIRS := Color(0.13, 0.16, 0.22)
const TEXT := Color(0.94, 0.96, 1.0)
const SUB := Color(0.55, 0.62, 0.74)

var phone: Control
var light := false


func build() -> void:
	add_child(UI.full(UI.rect(BG)))
	var header := UI.rect(BAR)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = phone.STATUS_H + 250
	add_child(header)
	var back := UI.text_button("‹", 90, BLUE, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	add_child(back)
	var title := UI.label("Чаты", 64, TEXT, UI.sans(700))
	title.position = Vector2(110, phone.STATUS_H + 10)
	add_child(title)
	var search := UI.panel(Color(1, 1, 1, 0.07), 26, 0)
	search.position = Vector2(50, phone.STATUS_H + 120)
	search.custom_minimum_size = Vector2(980, 96)
	var s := UI.label("    Поиск", 38, SUB)
	s.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search.add_child(s)
	add_child(search)

	var list := UI.scroller(self, phone.STATUS_H + 260, 40)
	for chat in _sorted(phone.chats):
		list.add_child(_chat_row(chat))


func _sorted(chats: Array) -> Array:
	var pinned := chats.filter(func(c: Dictionary) -> bool: return c.get("pinned", false))
	var rest := chats.filter(func(c: Dictionary) -> bool: return not c.get("pinned", false))
	return pinned + rest


func _chat_row(chat: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1080, 176)
	if chat.get("pinned", false):
		row.add_child(UI.full(UI.rect(Color(1, 1, 1, 0.03))))
	var av := _avatar(chat["name"], chat["color"], 116)
	av.position = Vector2(40, 30)
	row.add_child(av)
	var last: Array = chat["messages"][-1]
	var name := UI.label(chat["name"], 44, TEXT, UI.sans(600))
	name.position = Vector2(190, 34)
	name.size = Vector2(620, 56)
	name.clip_text = true
	row.add_child(name)
	var time := UI.label(last[2], 30, BLUE if int(chat["unread"]) > 0 else SUB)
	time.position = Vector2(830, 40)
	time.size = Vector2(200, 40)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(time)
	var preview := UI.label(("Вы: " if last[0] == "me" else "") + last[1], 36, SUB)
	preview.position = Vector2(190, 98)
	preview.size = Vector2(700, 50)
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(preview)
	if int(chat["unread"]) > 0:
		var badge := UI.label(str(chat["unread"]), 30, Color.WHITE, UI.sans(600))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", UI.box(BLUE, 26))
		badge.position = Vector2(970, 96)
		badge.size = Vector2(60, 52)
		row.add_child(badge)
	var line := UI.rect(Color(1, 1, 1, 0.06))
	line.position = Vector2(190, 174)
	line.size = Vector2(890, 2)
	row.add_child(line)
	UI.tap_area(row, _open_chat.bind(chat))
	return row


func _avatar(name: String, color: Color, d: float) -> Control:
	var av := Control.new()
	av.custom_minimum_size = Vector2(d, d)
	av.size = Vector2(d, d)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.draw.connect(func() -> void:
		av.draw_circle(Vector2(d, d) * 0.5, d * 0.5, color.darkened(0.15))
		av.draw_circle(Vector2(d, d) * 0.5 - Vector2(0, d * 0.06), d * 0.45, color)
		var f := UI.sans(600)
		var letter := name.left(1)
		var fs := int(d * 0.45)
		var sz := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		av.draw_string(f, Vector2((d - sz.x) * 0.5, d * 0.5 + fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE))
	return av


func _open_chat(chat: Dictionary) -> void:
	phone.emit_viewed("chat:" + chat["id"])
	chat["unread"] = 0
	var v := Control.new()
	var wall := Control.new()
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall.draw.connect(_draw_wallpaper.bind(wall))
	v.add_child(UI.full(UI.rect(BG)))
	v.add_child(UI.full(wall))

	var list := UI.scroller(v, phone.STATUS_H + 150, 150, 30)
	list.add_theme_constant_override("separation", 10)
	list.add_child(UI.spacer(20))
	var prev_who := ""
	for m in chat["messages"]:
		if m[0] == "day":
			var d := UI.label(m[1], 30, Color(1, 1, 1, 0.85), UI.sans(500))
			d.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.35), 24, 14))
			var holder := CenterContainer.new()
			holder.add_child(d)
			list.add_child(UI.spacer(10))
			list.add_child(holder)
			list.add_child(UI.spacer(10))
			prev_who = ""
		else:
			list.add_child(_bubble(m[1], m[2], m[0] == "me", m[0] != prev_who))
			prev_who = m[0]
	list.add_child(UI.spacer(20))

	var top := UI.rect(BAR)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = phone.STATUS_H + 140
	v.add_child(top)
	var back := UI.text_button("‹", 90, BLUE, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	v.add_child(back)
	var av := _avatar(chat["name"], chat["color"], 96)
	av.position = Vector2(110, phone.STATUS_H + 18)
	v.add_child(av)
	var name := UI.label(chat["name"], 42, TEXT, UI.sans(600))
	name.position = Vector2(230, phone.STATUS_H + 18)
	v.add_child(name)
	var status := UI.label(chat.get("status", ""), 30, BLUE if chat.get("status", "") == "в сети" else SUB)
	status.position = Vector2(230, phone.STATUS_H + 72)
	v.add_child(status)

	var input := UI.rect(BAR)
	input.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	input.offset_top = -150
	v.add_child(input)
	var field := UI.panel(Color(1, 1, 1, 0.07), 40, 0)
	field.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	field.offset_top = -126
	field.offset_bottom = -40
	field.offset_left = 50
	field.offset_right = -160
	var ph := UI.label("    Сообщение", 38, SUB)
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	field.add_child(ph)
	v.add_child(field)
	var mic := Control.new()
	mic.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mic.offset_left = -130
	mic.offset_top = -130
	mic.offset_right = -40
	mic.offset_bottom = -40
	mic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mic.draw.connect(func() -> void:
		mic.draw_circle(Vector2(45, 45), 45, BLUE)
		mic.draw_rect(Rect2(36, 20, 18, 32), Color.WHITE)
		mic.draw_circle(Vector2(45, 20), 9, Color.WHITE)
		mic.draw_circle(Vector2(45, 52), 9, Color.WHITE)
		mic.draw_arc(Vector2(45, 48), 18, 0.2, PI - 0.2, 12, Color.WHITE, 4)
		mic.draw_line(Vector2(45, 66), Vector2(45, 74), Color.WHITE, 4))
	v.add_child(mic)

	phone.push(v)
	# Conversations open at the newest message, like a real messenger.
	var scroll: ScrollContainer = v.get_meta("scroll")
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _draw_wallpaper(c: Control) -> void:
	# A faint doodle pattern, like a messenger's default chat background.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var col := Color(1, 1, 1, 0.025)
	for y in range(0, int(c.size.y), 140):
		for x in range(0, int(c.size.x), 140):
			var p := Vector2(x + rng.randf_range(10, 120), y + rng.randf_range(10, 120))
			match rng.randi() % 4:
				0:
					c.draw_arc(p, 16, 0, TAU, 16, col, 3)
				1:
					c.draw_line(p - Vector2(14, 0), p + Vector2(14, 0), col, 3)
					c.draw_line(p - Vector2(0, 14), p + Vector2(0, 14), col, 3)
				2:
					c.draw_rect(Rect2(p - Vector2(12, 12), Vector2(24, 24)), col, false, 3)
				3:
					c.draw_arc(p, 18, 0.3, PI - 0.3, 10, col, 3)


func _bubble(text: String, time: String, mine: bool, first_in_group: bool) -> Control:
	var row := HBoxContainer.new()
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := PanelContainer.new()
	var sb := UI.box(MINE if mine else THEIRS, 38)
	# The corner nearest the speaker is sharp on the first bubble: a tail.
	if first_in_group:
		if mine:
			sb.corner_radius_top_right = 8
		else:
			sb.corner_radius_top_left = 8
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 20
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var f := UI.sans()
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
	box.add_child(UI.label(text, 42, TEXT, null, minf(width + 8.0, 690.0)))
	var meta := UI.label(time + ("  ✓✓" if mine else ""), 26, Color(1, 1, 1, 0.55))
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(meta)
	if mine:
		row.add_child(gap)
		row.add_child(panel)
	else:
		row.add_child(panel)
		row.add_child(gap)
	return row
