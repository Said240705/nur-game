extends ScrollContainer
## Finger scrolling that never swallows a tap.
## The engine's own touch scrolling keeps coasting invisibly after a swipe, and
## the next tap only stops the coast instead of pressing what is under the
## finger, so on iPhone everything needed two taps. Here the coast stops at the
## first touch while the touch still reaches the button; a touch that turns
## into a drag marks the UI as dragging, so buttons ignore their release.

const UI := preload("res://scripts/ui/ui.gd")
const DRAG_THRESHOLD := 22.0

var _touch := -1
var _moved := 0.0
var _velocity := 0.0


func _ready() -> void:
	# Turn the built-in drag scrolling off; this script does the scrolling.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		# Every new touch starts as a tap until it moves.
		UI.dragging = false
	if not is_visible_in_tree() or not _on_top():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0 and get_global_rect().has_point(event.position):
			_touch = event.index
			_moved = 0.0
			_velocity = 0.0
		elif not event.pressed and event.index == _touch:
			_touch = -1
	elif event is InputEventScreenDrag and event.index == _touch:
		_moved += absf(event.relative.y)
		if _moved > DRAG_THRESHOLD:
			UI.dragging = true
			scroll_vertical -= int(event.relative.y)
			_velocity = lerpf(_velocity, -event.velocity.y, 0.6)
	elif event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll_vertical -= 120
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll_vertical += 120


func _process(delta: float) -> void:
	if _touch >= 0 or absf(_velocity) < 8.0:
		return
	scroll_vertical += int(_velocity * delta)
	_velocity *= pow(0.04, delta)


## Only a page that is shown and not covered by a modal card may scroll.
func _on_top() -> bool:
	return not UI.modal_open
