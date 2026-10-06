extends CanvasLayer
## Floating touch joystick plus a "Talk" button that appears near someone.

signal talk_pressed

const JOY_RADIUS := 110.0
const Texts := preload("res://scripts/texts.gd")

var _touch := -1
var _origin := Vector2.ZERO
var _current := Vector2.ZERO
var _view: Control
var _talk: Button


func _ready() -> void:
	layer = 10
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_on_draw)
	add_child(_view)

	_talk = Button.new()
	_talk.text = Texts.TALK
	_talk.focus_mode = Control.FOCUS_NONE
	_talk.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_talk.offset_left = -400.0
	_talk.offset_top = -230.0
	_talk.offset_right = -100.0
	_talk.offset_bottom = -110.0
	_talk.add_theme_font_size_override("font_size", 40)
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.06, 0.12, 0.8) if state != "pressed" else Color(0.3, 0.18, 0.08, 0.9)
		sb.border_color = Color(1.0, 0.74, 0.45)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(60)
		_talk.add_theme_stylebox_override(state, sb)
	_talk.add_theme_color_override("font_color", Color(1.0, 0.86, 0.66))
	_talk.visible = false
	_talk.pressed.connect(func() -> void: talk_pressed.emit())
	add_child(_talk)


func get_vector() -> Vector2:
	if _touch < 0:
		return Vector2.ZERO
	return ((_current - _origin) / JOY_RADIUS).limit_length(1.0)


func show_talk(on: bool) -> void:
	_talk.visible = on


func reset_touch() -> void:
	_touch = -1
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			# A finger that lands on the Talk button is a tap, not a walk.
			if _talk.visible and _talk.get_global_rect().grow(20).has_point(event.position):
				return
			_touch = event.index
			_origin = event.position
			_current = event.position
		elif not event.pressed and event.index == _touch:
			_touch = -1
		_view.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch:
		_current = event.position
		var off := _current - _origin
		if off.length() > JOY_RADIUS:
			_origin = _current - off.normalized() * JOY_RADIUS
		_view.queue_redraw()


func _on_draw() -> void:
	if _touch >= 0:
		_view.draw_arc(_origin, JOY_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.18), 3.0, true)
		_view.draw_circle(_origin + get_vector() * JOY_RADIUS, 30.0, Color(1, 1, 1, 0.22))
