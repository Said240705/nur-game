extends CanvasLayer
## Everything drawn over the phones: the current goal, Lev's passing thoughts,
## the doorbell prompt, the handwritten note and the button to swap phones.

signal door_opened
signal switch_pressed

const UI := preload("res://scripts/phone/ui.gd")
const INK := Color(0.16, 0.12, 0.1)
const WARM := Color(1.0, 0.8, 0.55)

var _goal: Label
var _thought: Label
var _thought_bg: Panel
var _switch: Button
var _door: Button
var _thought_id := 0
var _goal_id := 0


func _ready() -> void:
	# Above the film frames (panels) so the parcel note shows over the box.
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS

	_goal = Label.new()
	# The goal sits at the very bottom, under everything the phone shows.
	_goal.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_goal.offset_top = -100
	_goal.offset_bottom = -30
	_goal.offset_left = 60
	_goal.offset_right = -60
	_goal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.add_theme_font_override("font", UI.sans(600))
	_goal.add_theme_font_size_override("font_size", 32)
	_goal.add_theme_color_override("font_color", WARM)
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.55), 26, 20))
	_goal.visible = false
	add_child(_goal)

	_thought_bg = Panel.new()
	_thought_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_thought_bg.offset_top = -470
	_thought_bg.offset_bottom = -250
	_thought_bg.offset_left = 40
	_thought_bg.offset_right = -40
	_thought_bg.add_theme_stylebox_override("panel", _box(Color(0.03, 0.03, 0.05, 0.88), 30, 0, WARM))
	_thought_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thought_bg.modulate.a = 0.0
	add_child(_thought_bg)
	_thought = Label.new()
	_thought.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thought.offset_left = 40
	_thought.offset_right = -40
	_thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thought.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought.add_theme_font_override("font", UI.sans(500))
	_thought.add_theme_font_size_override("font_size", 40)
	_thought.add_theme_color_override("font_color", Color(0.96, 0.92, 0.86))
	_thought.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thought_bg.add_child(_thought)

	_switch = Button.new()
	_switch.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_switch.offset_left = -420
	_switch.offset_right = -40
	_switch.offset_top = -230
	_switch.offset_bottom = -130
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.add_theme_font_size_override("font_size", 34)
	_switch.add_theme_color_override("font_color", WARM)
	_switch.add_theme_stylebox_override("normal", _box(Color(0.05, 0.05, 0.08, 0.92), 50, 0, WARM))
	_switch.add_theme_stylebox_override("hover", _box(Color(0.05, 0.05, 0.08, 0.92), 50, 0, WARM))
	_switch.add_theme_stylebox_override("pressed", _box(Color(0.25, 0.16, 0.08, 0.95), 50, 0, WARM))
	_switch.visible = false
	_switch.pressed.connect(func() -> void: switch_pressed.emit())
	add_child(_switch)

	_door = Button.new()
	_door.set_anchors_preset(Control.PRESET_CENTER)
	_door.offset_left = -300
	_door.offset_right = 300
	_door.offset_top = -90
	_door.offset_bottom = 90
	_door.focus_mode = Control.FOCUS_NONE
	_door.add_theme_font_size_override("font_size", 52)
	_door.add_theme_color_override("font_color", WARM)
	_door.add_theme_stylebox_override("normal", _box(Color(0.05, 0.04, 0.03, 0.95), 90, 0, WARM))
	_door.add_theme_stylebox_override("hover", _box(Color(0.05, 0.04, 0.03, 0.95), 90, 0, WARM))
	_door.add_theme_stylebox_override("pressed", _box(Color(0.3, 0.2, 0.1, 0.95), 90, 0, WARM))
	_door.visible = false
	_door.pressed.connect(func() -> void:
		_door.visible = false
		door_opened.emit())
	add_child(_door)


## Shows the current goal for a while, then lets it fade so it never hides
## the bottom of an app for long.
func set_goal(text: String) -> void:
	_goal.text = text
	_goal.visible = text != ""
	_goal.modulate.a = 1.0
	_goal_id += 1
	var id := _goal_id
	await get_tree().create_timer(7.0).timeout
	if id == _goal_id and is_instance_valid(_goal):
		create_tween().tween_property(_goal, "modulate:a", 0.0, 1.0)


func show_switch(label: String) -> void:
	_switch.text = "⇄  " + label
	_switch.visible = label != ""


func show_door(label: String) -> void:
	_door.text = label
	_door.visible = true
	_door.scale = Vector2(0.8, 0.8)
	_door.pivot_offset = Vector2(300, 90)
	var tw := _door.create_tween().set_loops()
	tw.tween_property(_door, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_door, "scale", Vector2(0.96, 0.96), 0.6).set_trans(Tween.TRANS_SINE)


## A passing thought of Lev's at the bottom of the screen; fades by itself.
func think(text: String, seconds := 4.5) -> void:
	_thought_id += 1
	var id := _thought_id
	_thought.text = text
	var tw := create_tween()
	tw.tween_property(_thought_bg, "modulate:a", 1.0, 0.35)
	await get_tree().create_timer(seconds).timeout
	if id != _thought_id:
		return
	tw = create_tween()
	tw.tween_property(_thought_bg, "modulate:a", 0.0, 0.6)


## The handwritten note from the parcel; returns when it is tapped away.
func note(text: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var paper := PanelContainer.new()
	var sb := _box(Color(0.93, 0.89, 0.8), 6, 70)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 30
	paper.add_theme_stylebox_override("panel", sb)
	paper.position = Vector2(110, 520)
	paper.custom_minimum_size = Vector2(860, 0)
	paper.rotation = -0.025
	root.add_child(paper)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 720
	l.add_theme_font_override("font", UI.hand(600))
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("line_spacing", 4)
	paper.add_child(l)
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(2.0).timeout
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "pressed", "focus"]:
		tap.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	root.add_child(tap)
	await tap.pressed
	tw = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.5)
	await tw.finished
	root.queue_free()


## Lev puts the facts together: a question with a few answers over the phone.
## Returns the index of the chosen answer.
func choose(header: String, question: String, options: Array) -> int:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.offset_left = 90
	box.offset_right = -90
	box.offset_top = 520
	box.add_theme_constant_override("separation", 26)
	root.add_child(box)
	var h := UI.label(header, 34, WARM, UI.sans(700))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	var q := UI.label(question, 58, Color(0.96, 0.92, 0.86), UI.serif(true), 900)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(q)
	box.add_child(UI.spacer(20))
	var picked := {"i": -1}
	var done := func(i: int) -> void:
		if picked["i"] < 0:
			picked["i"] = i
			Sfx.play("click", -8.0)
	for i in options.size():
		var b := Button.new()
		b.text = options[i]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 130)
		b.add_theme_font_override("font", UI.sans(600))
		b.add_theme_font_size_override("font_size", 44)
		b.add_theme_color_override("font_color", WARM)
		b.add_theme_color_override("font_hover_color", WARM)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", _box(Color(0.06, 0.05, 0.05, 0.95), 65, 0, WARM))
		b.add_theme_stylebox_override("hover", _box(Color(0.06, 0.05, 0.05, 0.95), 65, 0, WARM))
		b.add_theme_stylebox_override("pressed", _box(Color(0.35, 0.22, 0.1, 0.95), 65, 0, WARM))
		b.pressed.connect(done.bind(i))
		box.add_child(b)
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.5)
	while picked["i"] < 0:
		await get_tree().process_frame
	tw = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.4)
	await tw.finished
	root.queue_free()
	return picked["i"]


func _box(color: Color, radius: int, margin: int, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.7
	sb.content_margin_bottom = margin * 0.7
	if border.a > 0.0:
		sb.border_color = Color(border, 0.6)
		sb.set_border_width_all(2)
	return sb
