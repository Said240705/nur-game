extends Node2D
## Footprints in the snow that fill in behind Nur.

const LIFE := 8.0
const MAX_PRINTS := 220

## Each print is [position, angle, age].
var _prints: Array = []


func add(pos: Vector2, angle: float) -> void:
	_prints.append([pos, angle, 0.0])
	if _prints.size() > MAX_PRINTS:
		_prints.pop_front()


func _process(delta: float) -> void:
	for p in _prints:
		p[2] += delta
	while not _prints.is_empty() and _prints[0][2] > LIFE:
		_prints.pop_front()
	queue_redraw()


func _draw() -> void:
	for p in _prints:
		var a: float = 0.45 * (1.0 - p[2] / LIFE)
		draw_set_transform(p[0], p[1], Vector2(1.5, 0.75))
		draw_circle(Vector2.ZERO, 3.2, Color(0.42, 0.45, 0.62, a))
	draw_set_transform(Vector2.ZERO)
