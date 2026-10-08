extends Control
## The night sky behind the game: a deep violet gradient, slowly drifting
## coloured lights and a few twinkling stars.

const Blocks := preload("res://scripts/game/blocks.gd")

var _orbs: Array = []
var _stars: Array = []
var _t := 0.0
var _lights: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("#2a1b66"), Color("#150f42"), Color("#070a24")])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 16
	tex.height = 256
	var sky := TextureRect.new()
	sky.texture = tex
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_lights = Control.new()
	_lights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = add
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	_lights.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 7:
		_orbs.append({"x": rng.randf(), "y": rng.randf(), "r": rng.randf_range(380, 760),
			"c": Blocks.PALETTE[(i * 3) % Blocks.PALETTE.size()], "sp": rng.randf_range(0.05, 0.12), "ph": rng.randf() * TAU})
	for i in 70:
		_stars.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(1.5, 3.5), rng.randf() * TAU))


func _process(delta: float) -> void:
	_t += delta
	_lights.queue_redraw()


func _draw_lights() -> void:
	var s := _lights.size
	var tex := Blocks.glow()
	for o in _orbs:
		var p := Vector2(o["x"] + sin(_t * o["sp"] + o["ph"]) * 0.12, o["y"] + cos(_t * o["sp"] * 0.8 + o["ph"]) * 0.07) * s
		var col: Color = o["c"]
		col.a = 0.09 + 0.03 * sin(_t * 0.4 + o["ph"])
		var r: float = o["r"]
		_lights.draw_texture_rect(tex, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
	for st in _stars:
		var a := 0.25 + 0.25 * sin(_t * 1.3 + st.w)
		_lights.draw_circle(Vector2(st.x, st.y) * s, st.z, Color(0.8, 0.85, 1.0, a))
