extends RefCounted
## Procedural textures and particle presets shared by the game and the title screen.


static func radial_texture(size: int, falloff := PackedFloat32Array([0.0, 0.45, 1.0]), alphas := PackedFloat32Array([1.0, 0.55, 0.0])) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = falloff
	var colors := PackedColorArray()
	for a in alphas:
		colors.append(Color(1, 1, 1, a))
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## Screen-space snowfall covering a view of the given size.
static func make_snow(view: Vector2, amount := 220, speed := 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 10.0 / speed
	p.preprocess = p.lifetime
	p.texture = radial_texture(16, PackedFloat32Array([0.0, 0.5, 1.0]), PackedFloat32Array([1.0, 0.6, 0.0]))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(view.x * 0.75, 8)
	p.position = Vector2(view.x * 0.5, -30)
	p.direction = Vector2(0.18, 1)
	p.spread = 14.0
	p.gravity = Vector2(10, 22) * speed
	p.initial_velocity_min = 45.0 * speed
	p.initial_velocity_max = 120.0 * speed
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.1
	p.color = Color(1, 1, 1, 0.85)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p
