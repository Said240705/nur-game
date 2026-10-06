extends CanvasLayer
## Level-up choice: three cards, the game stays paused until one is tapped.

signal chosen(id: String)

const Texts := preload("res://scripts/texts.gd")
const GLOW := Color(1.0, 0.72, 0.42)

var _root: Control
var _row: HBoxContainer
var _title: Label
var _sub: Label


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.01, 0.03, 0.72)
	_root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_root.add_child(box)

	_title = Label.new()
	_title.text = Texts.UPGRADE_TITLE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.78))
	box.add_child(_title)
	_sub = Label.new()
	_sub.text = Texts.UPGRADE_SUB
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 28)
	_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(_sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	box.add_child(gap)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 36)
	box.add_child(_row)


func open(ids: Array) -> void:
	for c in _row.get_children():
		c.queue_free()
	for id in ids:
		_row.add_child(_card(id))
	visible = true
	_root.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 1.0, 0.35)
	# Ignore taps for a moment so a finger still moving Nur doesn't pick blindly.
	for c in _row.get_children():
		(c as Button).disabled = true
	await get_tree().create_timer(0.6, true).timeout
	for c in _row.get_children():
		if is_instance_valid(c):
			(c as Button).disabled = false


func _card(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 300)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.25)))
	b.add_theme_stylebox_override("hover", _style(GLOW))
	b.add_theme_stylebox_override("pressed", _style(GLOW))
	b.add_theme_stylebox_override("disabled", _style(Color(1, 1, 1, 0.12)))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var title := Label.new()
	title.text = Texts.UPGRADES[id][0]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.66))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(title)

	var desc := Label.new()
	desc.text = Texts.UPGRADES[id][1]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(340, 0)
	desc.add_theme_font_size_override("font_size", 28)
	desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)

	b.pressed.connect(_pick.bind(id))
	return b


func _style(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 24
	s.content_margin_right = 24
	return s


func _pick(id: String) -> void:
	visible = false
	chosen.emit(id)
