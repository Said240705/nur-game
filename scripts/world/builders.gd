extends RefCounted
## Procedural meshes and material helpers for the 3D world.

const SNOWY := preload("res://shaders/snowy.gdshader")
const FAR := preload("res://shaders/far_mountain.gdshader")


## Re-skins every mesh under `root` with the snow-cover shader, keeping its texture.
static func snowify(root: Node, snow := 0.55, darken := 0.8) -> void:
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = SNOWY
			if src is BaseMaterial3D:
				mat.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
			mat.set_shader_parameter("snow_amount", snow)
			mat.set_shader_parameter("darken", darken)
			m.set_surface_override_material(i, mat)


## Flat-shaded, hazy material for the mountains on the horizon.
static func far_material(haze: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FAR
	mat.set_shader_parameter("haze", haze)
	return mat


static func set_far(root: Node, mat: Material) -> void:
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A craggy peak: rings of vertices from summit to base, pushed in and out by
## angular ridges so each mountain has its own silhouette. Unit height, unit base radius.
static func mountain_mesh(seed: int, rings := 14, segments := 40) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var phases: Array[float] = []
	for k in 4:
		phases.append(rng.randf() * TAU)
	var lean := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
	var pts: Array = []
	for r in rings + 1:
		var t := float(r) / rings
		var row: Array[Vector3] = []
		for j in segments:
			var a := TAU * j / segments
			var ridge := 0.22 * sin(a * 3.0 + phases[0]) + 0.13 * sin(a * 7.0 + phases[1]) + 0.07 * sin(a * 13.0 + phases[2])
			var rad := pow(t, 0.85) * (1.0 + ridge * (0.4 + t))
			var y := 1.0 - t
			y -= 0.06 * sin(a * 5.0 + phases[3]) * t * (1.0 - t) * 4.0
			var off := lean * (1.0 - t)
			row.append(Vector3(cos(a) * rad + off.x, maxf(y, 0.0), sin(a) * rad + off.y))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings:
		for j in segments:
			var j2 := (j + 1) % segments
			var a: Vector3 = pts[r][j]
			var b: Vector3 = pts[r][j2]
			var c: Vector3 = pts[r + 1][j]
			var d: Vector3 = pts[r + 1][j2]
			for v in [a, d, b, a, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## A veiled figure: a smooth head with no face over a long robe that frays at the hem.
static func ghost_mesh() -> ArrayMesh:
	var profile := [
		Vector2(0.0, 1.95), Vector2(0.09, 1.93), Vector2(0.145, 1.86), Vector2(0.155, 1.76),
		Vector2(0.13, 1.66), Vector2(0.1, 1.6), Vector2(0.21, 1.5), Vector2(0.255, 1.32),
		Vector2(0.265, 1.05), Vector2(0.3, 0.65), Vector2(0.36, 0.28), Vector2(0.43, 0.0),
	]
	return lathe(profile, 20)


## Revolves a (radius, height) profile around the Y axis.
static func lathe(profile: Array, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: float = profile[0].y
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for j in segments:
			var t0 := TAU * j / segments
			var t1 := TAU * (j + 1) / segments
			var p00 := Vector3(cos(t0) * a.x, a.y, sin(t0) * a.x)
			var p01 := Vector3(cos(t1) * a.x, a.y, sin(t1) * a.x)
			var p10 := Vector3(cos(t0) * b.x, b.y, sin(t0) * b.x)
			var p11 := Vector3(cos(t1) * b.x, b.y, sin(t1) * b.x)
			var u0 := float(j) / segments
			var u1 := float(j + 1) / segments
			for v in [[p00, u0, a.y], [p01, u1, a.y], [p11, u1, b.y], [p00, u0, a.y], [p11, u1, b.y], [p10, u0, b.y]]:
				st.set_uv(Vector2(v[1], 1.0 - v[2] / top))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Soft round texture used for snowflakes and glows.
static func dot_texture(size := 32) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = size
	tex.height = size
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


static func emissive(color: Color, energy: float, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
