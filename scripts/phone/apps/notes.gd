extends Control
## Notes: a warm paper app. The list is a stack of cards; a note opens on ruled
## paper with a red margin, written in Lev's own hand.

const UI := preload("res://scripts/phone/ui.gd")
const PAPER := Color(0.97, 0.95, 0.89)
const INK := Color(0.16, 0.14, 0.12)
const PENCIL := Color(0.42, 0.38, 0.34)
const AMBER := Color(0.85, 0.6, 0.08)
const RULE := Color(0.45, 0.62, 0.82, 0.35)
const MARGIN := Color(0.85, 0.3, 0.3, 0.45)
const LINE_H := 84.0

var phone: Control
var light := true


func build() -> void:
	add_child(UI.full(UI.rect(PAPER)))
	add_child(_back("Назад"))
	var title := UI.label("Заметки", 76, INK, UI.sans(700))
	title.position = Vector2(60, phone.STATUS_H + 110)
	add_child(title)
	var count := UI.label("%d заметки" % phone.data.NOTES.size(), 34, PENCIL)
	count.position = Vector2(64, phone.STATUS_H + 210)
	add_child(count)

	var list := UI.scroller(self, phone.STATUS_H + 290, 40, 50)
	list.add_theme_constant_override("separation", 26)
	for n in phone.data.NOTES:
		list.add_child(_card(n))


func _back(text: String) -> Button:
	var b := UI.text_button("‹ " + text, 44, AMBER, phone.pop, UI.sans(500))
	b.position = Vector2(30, phone.STATUS_H)
	b.custom_minimum_size = Vector2(260, 100)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _card(n: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := UI.box(Color(1, 1, 1, 0.85), 28, 36)
	sb.shadow_color = Color(0.4, 0.3, 0.1, 0.12)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	v.add_child(UI.label(n["title"], 46, INK, UI.sans(600)))
	var first: String = n["body"].split("\n")[0]
	var preview := UI.label("%s   %s" % [n["date"], first], 34, PENCIL)
	preview.clip_text = true
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview.custom_minimum_size.x = 880
	v.add_child(preview)
	UI.tap_area(card, _open.bind(n), Color(0.85, 0.6, 0.08, 0.12))
	return card


func _open(n: Dictionary) -> void:
	phone.emit_viewed("note:" + n["id"])
	var v := Control.new()
	v.add_child(UI.full(UI.rect(PAPER)))
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func() -> void:
		var y: float = phone.STATUS_H + 330.0
		while y < lines.size.y:
			lines.draw_line(Vector2(0, y), Vector2(lines.size.x, y), RULE, 2)
			y += LINE_H
		lines.draw_line(Vector2(120, 0), Vector2(120, lines.size.y), MARGIN, 3))
	v.add_child(UI.full(lines))
	v.add_child(_back("Заметки"))

	var title := UI.label(n["title"], 64, INK, UI.sans(700), 860)
	title.position = Vector2(150, phone.STATUS_H + 120)
	v.add_child(title)
	var date := UI.label(n["date"], 32, PENCIL)
	date.position = Vector2(150, phone.STATUS_H + 215)
	v.add_child(date)

	var body := UI.label(n["body"], 60, INK, UI.hand(500), 860)
	# Line spacing tuned so the handwriting sits on the ruled lines.
	body.add_theme_constant_override("line_spacing", int(LINE_H - 60 * 1.2))
	body.position = Vector2(150, phone.STATUS_H + 330 - 66)
	v.add_child(body)
	phone.push(v, true)
