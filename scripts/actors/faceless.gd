extends Node2D
## A Faceless: someone the valley has forgotten. Pale, veiled, drifting like smoke.
## It does not attack; it waits. Give back what it lost and its face returns.

const HEIGHT := 120.0

var faded := 0.0
## 0 = blank veil, 1 = the face has come back (warm, then it dissolves).
var remembered := 0.0

var _t := randf() * 10.0
var _appear := 0.0


func _ready() -> void:
	# Faceless glow on their own so they read through the night and the fog.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	_appear = minf(1.0, _appear + delta * 0.35)
	queue_redraw()


func _draw() -> void:
	var fade := _appear * (1.0 - faded)
	if fade <= 0.0:
		return
	var s := HEIGHT / 80.0
	var sway := sin(_t * 1.5) * 4.0
	var cold := Color(0.82, 0.86, 0.95, 0.62 * fade)
	var warm := Color(1.0, 0.86, 0.68, 0.8 * fade)
	var body := cold.lerp(warm, remembered)

	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 20.0 * s, Color(0.05, 0.08, 0.2, 0.25 * fade))
	draw_set_transform(Vector2.ZERO)

	# A soft halo so the figure seems to give off cold light.
	for i in 4:
		draw_circle(Vector2(sway * 0.5, -40.0 * s), (26.0 + i * 10.0) * s, Color(body, 0.05 * fade))

	var shape := [
		Vector2(-10, -60), Vector2(10, -60), Vector2(17, -30), Vector2(15, -6),
		Vector2(10, 0), Vector2(5, -7), Vector2(0, 2), Vector2(-5, -7),
		Vector2(-10, 0), Vector2(-15, -6), Vector2(-17, -30),
	]
	var pts := PackedVector2Array()
	for p: Vector2 in shape:
		var k := -p.y / 60.0
		var wisp := sin(_t * 5.0 + p.x) * 2.0 if p.y > -8.0 else 0.0
		pts.append(Vector2(p.x + sway * k + wisp, p.y) * s)
	draw_colored_polygon(pts, body)

	var head := Vector2(sway, -72) * s
	draw_set_transform(head, 0.0, Vector2(1.0, 1.22))
	draw_circle(Vector2.ZERO, 11.0 * s, body)
	if remembered < 0.5:
		# The blank face: no eyes, no mouth, only a slightly hollow oval.
		draw_circle(Vector2(0, 1.5 * s), 7.0 * s, Color(0.5, 0.55, 0.68, 0.75 * fade * (1.0 - remembered * 2.0)))
	else:
		# The face comes back: two eyes and a small smile.
		var a := (remembered - 0.5) * 2.0 * fade
		var ink := Color(0.25, 0.16, 0.12, a)
		draw_circle(Vector2(-3.6, 0) * s, 1.3 * s, ink)
		draw_circle(Vector2(3.6, 0) * s, 1.3 * s, ink)
		draw_arc(Vector2(0, 3.2) * s, 3.0 * s, 0.3, PI - 0.3, 10, ink, 0.9 * s, true)
		draw_circle(Vector2(-6, 2.5) * s, 1.8 * s, Color(1.0, 0.55, 0.45, 0.35 * a))
		draw_circle(Vector2(6, 2.5) * s, 1.8 * s, Color(1.0, 0.55, 0.45, 0.35 * a))
	draw_set_transform(Vector2.ZERO)
