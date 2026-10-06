extends Control
## Voicemail in the style of a phone app: a list with green play buttons; a
## message opens to a waveform that fills while its transcript types itself out.

const UI := preload("res://scripts/phone/ui.gd")
const BG := Color(0.04, 0.045, 0.05)
const TEXT := Color(0.95, 0.96, 0.97)
const SUB := Color(0.55, 0.58, 0.6)
const GREEN := Color(0.24, 0.82, 0.46)

var phone: Control
var light := false


func build() -> void:
	add_child(UI.full(UI.rect(BG)))
	var back := UI.text_button("‹", 90, GREEN, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	add_child(back)
	var title := UI.label("Автоответчик", 72, TEXT, UI.sans(700))
	title.position = Vector2(60, phone.STATUS_H + 110)
	add_child(title)
	var list := UI.scroller(self, phone.STATUS_H + 240, 40, 40)
	list.add_theme_constant_override("separation", 0)
	for vm in phone.data.VOICEMAIL:
		list.add_child(_row(vm))


func _row(vm: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(1000, 170)
	var play := Control.new()
	play.position = Vector2(10, 40)
	play.size = Vector2(90, 90)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.draw.connect(func() -> void:
		play.draw_circle(Vector2(45, 45), 45, GREEN)
		play.draw_colored_polygon(PackedVector2Array([Vector2(36, 26), Vector2(66, 45), Vector2(36, 64)]), Color.WHITE))
	row.add_child(play)
	var who := UI.label(vm["from"], 46, TEXT, UI.sans(600))
	who.position = Vector2(130, 36)
	row.add_child(who)
	var meta := UI.label("%s · %s" % [vm["time"], vm["length"]], 34, SUB)
	meta.position = Vector2(130, 96)
	row.add_child(meta)
	var line := UI.rect(Color(1, 1, 1, 0.07))
	line.position = Vector2(130, 168)
	line.size = Vector2(870, 2)
	row.add_child(line)
	UI.tap_area(row, _open.bind(vm))
	return row


func _open(vm: Dictionary) -> void:
	phone.emit_viewed("vm:" + vm["id"])
	var v := Control.new()
	v.add_child(UI.full(UI.rect(BG)))
	var back := UI.text_button("‹", 90, GREEN, phone.pop, UI.sans(300))
	back.position = Vector2(20, phone.STATUS_H - 6)
	v.add_child(back)

	var av := Control.new()
	av.position = Vector2(390, phone.STATUS_H + 120)
	av.size = Vector2(300, 300)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.draw.connect(func() -> void:
		av.draw_circle(Vector2(150, 150), 150, Color(0.2, 0.22, 0.24))
		av.draw_circle(Vector2(150, 118), 56, SUB)
		av.draw_arc(Vector2(150, 290), 110, PI + 0.3, TAU - 0.3, 24, SUB, 60))
	v.add_child(av)
	var who := UI.label(vm["from"], 56, TEXT, UI.sans(700))
	who.set_anchors_preset(Control.PRESET_TOP_WIDE)
	who.offset_top = phone.STATUS_H + 450
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	var meta := UI.label("Голосовое сообщение · %s · %s" % [vm["time"], vm["length"]], 34, SUB)
	meta.set_anchors_preset(Control.PRESET_TOP_WIDE)
	meta.offset_top = phone.STATUS_H + 530
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(meta)

	var progress := {"t": 0.0}
	var wave := Control.new()
	wave.position = Vector2(60, phone.STATUS_H + 640)
	wave.size = Vector2(960, 180)
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.draw.connect(func() -> void:
		var bars := 44
		for i in bars:
			var h := 20.0 + 130.0 * absf(sin(i * 1.7) * cos(i * 0.6))
			var played: bool = float(i) / bars < float(progress["t"])
			wave.draw_line(Vector2(10 + i * 21.8, 90 - h * 0.5), Vector2(10 + i * 21.8, 90 + h * 0.5), GREEN if played else Color(1, 1, 1, 0.22), 10))
	v.add_child(wave)

	var card := UI.panel(Color(1, 1, 1, 0.05), 34, 40)
	card.position = Vector2(50, phone.STATUS_H + 860)
	card.custom_minimum_size = Vector2(980, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)
	vb.add_child(UI.label("РАСШИФРОВКА", 28, SUB, UI.sans(700)))
	var text := UI.label("", 44, TEXT, null, 900)
	text.add_theme_constant_override("line_spacing", 8)
	vb.add_child(text)
	v.add_child(card)
	phone.push(v)

	# "Playing" the message: the waveform fills and the transcript types itself out.
	var full: String = vm["transcript"]
	text.text = full
	text.visible_characters = 0
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		progress["t"] = k
		text.visible_characters = int(full.length() * k)
		wave.queue_redraw(), 0.0, 1.0, maxf(2.5, full.length() / 22.0))
