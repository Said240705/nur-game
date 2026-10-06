extends CanvasLayer
## Minimal in-game HUD plus the floating touch joystick.
## Bars: warm light (health) and pale memory (experience); diamonds: memory fragments.

const JOY_RADIUS := 110.0
const GLOW := Color(1.0, 0.72, 0.42)

var _light := 1.0
var _xp := 0.0
var _memories := 0
var _touch := -1
var _origin := Vector2.ZERO
var _current := Vector2.ZERO
var _view: Control


func _ready() -> void:
	layer = 10
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_on_draw)
	add_child(_view)


func get_vector() -> Vector2:
	if _touch < 0:
		return Vector2.ZERO
	return ((_current - _origin) / JOY_RADIUS).limit_length(1.0)


func reset_touch() -> void:
	_touch = -1
	_view.queue_redraw()


func update_stats(light: float, xp: float) -> void:
	_light = light
	_xp = xp
	_view.queue_redraw()


func set_memories(count: int) -> void:
	_memories = count
	_view.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			_touch = event.index
			_origin = event.position
			_current = event.position
		elif not event.pressed and event.index == _touch:
			_touch = -1
		_view.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch:
		_current = event.position
		# Floating stick: the base follows a finger that drags too far.
		var off := _current - _origin
		if off.length() > JOY_RADIUS:
			_origin = _current - off.normalized() * JOY_RADIUS
		_view.queue_redraw()


func _on_draw() -> void:
	var size := _view.get_viewport_rect().size
	var w := 460.0
	var x := (size.x - w) * 0.5
	var y := 40.0
	_view.draw_rect(Rect2(x, y, w, 5), Color(1, 1, 1, 0.12))
	_view.draw_rect(Rect2(x, y, w * _light, 5), Color(GLOW, 0.95))
	_view.draw_rect(Rect2(x, y + 13, w, 3), Color(1, 1, 1, 0.08))
	_view.draw_rect(Rect2(x, y + 13, w * _xp, 3), Color(0.86, 0.9, 1.0, 0.75))

	for i in 5:
		var c := Vector2(x + w + 46 + i * 28, y + 8)
		var d := PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 0), c + Vector2(0, 9), c + Vector2(-6, 0), c + Vector2(0, -9)])
		if i < _memories:
			_view.draw_colored_polygon(d, Color(1.0, 0.92, 0.78))
		else:
			_view.draw_polyline(d, Color(1, 1, 1, 0.3), 1.5, true)

	if _touch >= 0:
		_view.draw_arc(_origin, JOY_RADIUS, 0.0, TAU, 64, Color(1, 1, 1, 0.16), 2.0, true)
		_view.draw_circle(_origin + get_vector() * JOY_RADIUS, 28.0, Color(1, 1, 1, 0.2))
