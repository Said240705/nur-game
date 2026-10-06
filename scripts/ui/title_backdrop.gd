extends Node2D
## The postcard behind the intro and title: a sleeping village under the White Peak.

const Fx := preload("res://scripts/fx.gd")

var _stars: Array = []
var _ridges: Array[PackedFloat32Array] = []
var _houses: Array = []
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.55), rng.randf_range(0.6, 1.9), rng.randf() * TAU])
	_ridges.append(_ridge(rng, 0.60, 0.10, 9))
	_ridges.append(_ridge(rng, 0.72, 0.06, 14))
	_ridges.append(_ridge(rng, 0.83, 0.03, 20))
	for i in 9:
		_houses.append([0.24 + i * 0.055 + rng.randf_range(-0.01, 0.01), rng.randf_range(0.8, 1.2), rng.randf() < 0.75, rng.randf() * TAU])
	add_child(Fx.make_snow(get_viewport_rect().size, 180, 0.8))


func _ridge(rng: RandomNumberGenerator, base: float, amp: float, n: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	for i in n + 1:
		h.append(base + rng.randf_range(-amp, amp))
	return h


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _height(h: PackedFloat32Array, x: float) -> float:
	var f := x * (h.size() - 1)
	var i := mini(int(f), h.size() - 2)
	var k := f - i
	k = k * k * (3.0 - 2.0 * k)
	return lerpf(h[i], h[i + 1], k)


func _draw() -> void:
	var s := get_viewport_rect().size
	var w := s.x
	var h := s.y

	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0.01, 0.015, 0.04), Color(0.01, 0.015, 0.04), Color(0.1, 0.12, 0.19), Color(0.1, 0.12, 0.19)]))

	for st in _stars:
		var a: float = 0.35 + 0.35 * sin(_t * 1.3 + st[2])
		draw_circle(st[0] * s, st[1], Color(1, 1, 1, a))

	var moon := Vector2(w * 0.78, h * 0.17)
	for i in 5:
		draw_circle(moon, 34.0 + i * 26.0, Color(0.8, 0.85, 1.0, 0.035))
	draw_circle(moon, 32.0, Color(0.9, 0.92, 0.97))

	# The White Peak.
	var peak := PackedVector2Array([
		Vector2(w * 0.12, h * 0.8), Vector2(w * 0.3, h * 0.5), Vector2(w * 0.38, h * 0.42),
		Vector2(w * 0.46, h * 0.22), Vector2(w * 0.5, h * 0.13), Vector2(w * 0.54, h * 0.21),
		Vector2(w * 0.6, h * 0.36), Vector2(w * 0.7, h * 0.47), Vector2(w * 0.88, h * 0.8),
	])
	draw_colored_polygon(peak, Color(0.17, 0.19, 0.26))
	var cap := PackedVector2Array([
		Vector2(w * 0.43, h * 0.29), Vector2(w * 0.46, h * 0.22), Vector2(w * 0.5, h * 0.13),
		Vector2(w * 0.54, h * 0.21), Vector2(w * 0.57, h * 0.3), Vector2(w * 0.53, h * 0.27),
		Vector2(w * 0.5, h * 0.31), Vector2(w * 0.47, h * 0.26),
	])
	draw_colored_polygon(cap, Color(0.72, 0.76, 0.84))

	var tones := [Color(0.1, 0.12, 0.17), Color(0.06, 0.07, 0.1), Color(0.025, 0.03, 0.045)]
	for li in _ridges.size():
		var pts := PackedVector2Array([Vector2(0, h)])
		for xi in 97:
			var x := xi / 96.0
			pts.append(Vector2(x * w, _height(_ridges[li], x) * h))
		pts.append(Vector2(w, h))
		draw_colored_polygon(pts, tones[li])

	# Village on the nearest ridge; lit windows are the only warm colour.
	var front := _ridges[2]
	for hs in _houses:
		var x: float = hs[0] * w
		var base := _height(front, hs[0]) * h + 6.0
		var sc: float = hs[1] * h / 1080.0
		var bw := 46.0 * sc
		var bh := 30.0 * sc
		draw_rect(Rect2(x - bw * 0.5, base - bh, bw, bh), Color(0.015, 0.018, 0.028))
		draw_colored_polygon(PackedVector2Array([Vector2(x - bw * 0.62, base - bh), Vector2(x, base - bh - 22.0 * sc), Vector2(x + bw * 0.62, base - bh)]), Color(0.015, 0.018, 0.028))
		if hs[2]:
			var flick: float = 0.85 + 0.15 * sin(_t * 7.0 + hs[3]) * sin(_t * 3.1 + hs[3])
			var win := Vector2(x - 4.0 * sc, base - bh * 0.62)
			draw_circle(win + Vector2(4, 5) * sc, 22.0 * sc, Color(1.0, 0.6, 0.3, 0.12 * flick))
			draw_rect(Rect2(win, Vector2(9, 10) * sc), Color(1.0, 0.72, 0.4, flick))
