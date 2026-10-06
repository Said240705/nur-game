extends Node2D
## A lost keepsake glowing in the snow: the thing a Faceless is searching for.

var taken := false
var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if taken:
		return
	var pulse := 0.6 + 0.4 * sin(_t * 3.0)
	for i in 5:
		draw_circle(Vector2(0, -6), 6.0 + i * 6.0, Color(1.0, 0.8, 0.5, 0.07 * pulse))
	# A tiny wooden horse: body, neck, head, legs.
	var wood := Color(0.55, 0.33, 0.18)
	draw_rect(Rect2(-7, -10, 13, 6), wood)
	draw_line(Vector2(4, -10), Vector2(7, -16), wood, 3.0, true)
	draw_rect(Rect2(5, -19, 6, 4), wood)
	for x in [-6.0, -2.0, 2.0, 5.0]:
		draw_line(Vector2(x, -4), Vector2(x, 0), wood.darkened(0.2), 1.6, true)
	draw_circle(Vector2(0, -7), 1.4, Color(1.0, 0.9, 0.7, pulse))
