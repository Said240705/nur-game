extends Control
## Sparks and confetti, drawn as glowing dots added on top of everything.

const Blocks := preload("res://scripts/game/blocks.gd")

var _parts: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


## Sparks flying out of a cleared square.
func burst(at: Vector2, color: Color, n := 6, speed := 700.0) -> void:
	for i in n:
		var dir := Vector2.from_angle(randf() * TAU)
		_parts.append({"p": at, "v": dir * randf_range(0.25, 1.0) * speed + Vector2(0, -250),
			"life": randf_range(0.45, 0.85), "t": 0.0, "c": color, "s": randf_range(14.0, 30.0), "g": 1300.0})


## A shower of colours from the top, for a new record.
func confetti(width: float) -> void:
	for i in 90:
		var c: Color = Blocks.PALETTE[i % Blocks.PALETTE.size()]
		_parts.append({"p": Vector2(randf() * width, randf_range(-300, -20)), "v": Vector2(randf_range(-120, 120), randf_range(200, 600)),
			"life": randf_range(1.8, 3.0), "t": 0.0, "c": c, "s": randf_range(16.0, 28.0), "g": 300.0})


func _process(delta: float) -> void:
	for p in _parts:
		p["t"] += delta
		p["v"] += Vector2(0, p["g"]) * delta
		p["v"] *= pow(0.2, delta)
		p["p"] += p["v"] * delta
	_parts = _parts.filter(func(p: Dictionary) -> bool: return p["t"] < p["life"])
	queue_redraw()


func _draw() -> void:
	var tex := Blocks.glow()
	for p in _parts:
		var k: float = p["t"] / p["life"]
		var col: Color = p["c"]
		col.a = 1.0 - k
		var r: float = p["s"] * (1.0 - k * 0.5)
		draw_texture_rect(tex, Rect2(p["p"] - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, col)
		draw_circle(p["p"], r * 0.28, Color(1, 1, 1, (1.0 - k) * 0.9))
