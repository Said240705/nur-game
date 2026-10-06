extends Node3D
## The valley: night sky, endless snowfield, the village, forest, distant peaks,
## falling snow and the camera. Gameplay and cutscenes both look through `camera`.

const B := preload("res://scripts/world/builders.gd")
const SKY := preload("res://shaders/sky.gdshader")
const GROUND := preload("res://shaders/snow_ground.gdshader")

const ENV := "res://assets/env/"
const CELL := 24.0
const VILLAGE_RADIUS := 34.0
## Direction of the White Peak from the village (towards -Z, a little to the east).
const PEAK_DIR := Vector3(0.25, 0.0, -1.0)

enum CamMode { SHOT, FOLLOW }

## Phones and browsers get a lighter forest and less snow.
var low_end := OS.has_feature("web") or OS.has_feature("mobile")
var cell_radius := 3 if low_end else 4

var camera: Camera3D
var env: Environment
## Point the endless pieces (ground, forest, horizon) stay centred on.
var focus := Vector3.ZERO

var cam_mode := CamMode.SHOT
var follow_target: Node3D
var follow_offset := Vector3(0, 6.4, 8.2)
var _follow_blend := 1.0
var _blend_from := Transform3D()
var _blend_speed := 1.0
var _dolly: Tween

var _ground: MeshInstance3D
var _horizon: Node3D
var _snow: CPUParticles3D
var _cells := {}
var _scatter_scenes: Array[PackedScene] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_horizon()
	_build_village()
	for n in ["tree_single_A", "tree_single_B", "trees_A_large", "trees_B_large", "rock_single_A", "rock_single_C", "rock_single_D"]:
		_scatter_scenes.append(load(ENV + n + ".gltf"))

	camera = Camera3D.new()
	camera.fov = 48.0
	camera.far = 2500.0
	add_child(camera)
	camera.make_current()

	_snow = _make_snow()
	camera.add_child(_snow)
	_update_cells()


## Thicker fog when Nur's light is weak: the Silence closes in.
func set_silence(light_ratio: float) -> void:
	env.fog_density = lerpf(0.055, 0.022, light_ratio)


## Hard cut to a framed shot.
func shot(from: Vector3, look_at_point: Vector3) -> void:
	if _dolly and _dolly.is_valid():
		_dolly.kill()
	cam_mode = CamMode.SHOT
	camera.global_position = from
	camera.look_at(look_at_point)


## Glide the camera along a straight move, like a dolly shot.
func dolly(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, seconds: float) -> Tween:
	cam_mode = CamMode.SHOT
	if _dolly and _dolly.is_valid():
		_dolly.kill()
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void:
		camera.global_position = from.lerp(to, k)
		camera.look_at(look_from.lerp(look_to, k)), 0.0, 1.0, seconds)
	_dolly = tw
	return tw


## Hand the camera to gameplay, easing from wherever it is now.
func follow(target: Node3D, blend_seconds := 2.0) -> void:
	if _dolly and _dolly.is_valid():
		_dolly.kill()
	follow_target = target
	cam_mode = CamMode.FOLLOW
	_blend_from = camera.global_transform
	_blend_speed = 1.0 / maxf(blend_seconds, 0.01)
	_follow_blend = 0.0 if blend_seconds > 0.0 else 1.0


func _follow_pose() -> Transform3D:
	var t := Transform3D(Basis(), focus + follow_offset)
	return t.looking_at(focus + Vector3(0, 1.0, 0))


func _process(delta: float) -> void:
	if cam_mode == CamMode.FOLLOW and is_instance_valid(follow_target):
		focus = follow_target.global_position
		if _follow_blend < 1.0:
			_follow_blend = minf(1.0, _follow_blend + delta * _blend_speed)
			var k := ease(_follow_blend, -2.2)
			camera.global_transform = _blend_from.interpolate_with(_follow_pose(), k)
		else:
			camera.global_transform = camera.global_transform.interpolate_with(_follow_pose(), minf(1.0, delta * 4.0))
	elif cam_mode == CamMode.SHOT:
		focus = Vector3(camera.global_position.x, 0, camera.global_position.z)

	_ground.global_position = Vector3(snappedf(focus.x, 4.0), 0, snappedf(focus.z, 4.0))
	_horizon.global_position = Vector3(focus.x, 0, focus.z)
	_update_cells()


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.66)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.3, 0.37, 0.54)
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0 if low_end else 60.0
	moon.rotation_degrees = Vector3(-32, 150, 0)
	add_child(moon)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND
	plane.material = mat
	_ground = MeshInstance3D.new()
	_ground.mesh = plane
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground)


## Peaks on the horizon travel with the camera so the valley feels endless.
func _build_horizon() -> void:
	_horizon = Node3D.new()
	add_child(_horizon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var near_mat := B.far_material(0.5)
	var far_mat := B.far_material(0.62)
	for i in 30:
		var ang := TAU * i / 30.0 + rng.randf_range(-0.06, 0.06)
		var dir := Vector3(sin(ang), 0, cos(ang))
		if dir.dot(PEAK_DIR.normalized()) > 0.95:
			continue
		var far := i % 2 == 0
		var m := MeshInstance3D.new()
		m.mesh = B.mountain_mesh(rng.randi())
		m.material_override = far_mat if far else near_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = dir * (rng.randf_range(620.0, 700.0) if far else rng.randf_range(420.0, 480.0))
		var w := rng.randf_range(120.0, 180.0) * (1.5 if far else 1.0)
		m.scale = Vector3(w, w * rng.randf_range(0.45, 0.7), w)
		m.rotation.y = rng.randf() * TAU
		_horizon.add_child(m)

	# The White Peak towers over everything.
	var peak := MeshInstance3D.new()
	peak.mesh = B.mountain_mesh(4242, 18, 56)
	var peak_mat := B.far_material(0.32)
	peak_mat.set_shader_parameter("snow_color", Color(0.86, 0.9, 1.0))
	peak_mat.set_shader_parameter("snow_line", 0.25)
	peak.material_override = peak_mat
	peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	peak.position = PEAK_DIR.normalized() * 1100.0
	peak.scale = Vector3(420, 420, 420)
	_horizon.add_child(peak)


func _build_village() -> void:
	var houses := [
		["building_home_A_red", Vector3(-11, 0, -12), 0.6],
		["building_home_B_red", Vector3(9, 0, -16), -0.5],
		["building_tavern_red", Vector3(19, 0, -4), -1.4],
		["building_home_A_red", Vector3(-19, 0, 3), 1.7],
		["building_church_red", Vector3(-4, 0, -27), 0.1],
		["building_home_B_red", Vector3(15, 0, 11), -2.3],
		["building_home_A_red", Vector3(-12, 0, 15), 2.6],
	]
	for h in houses:
		var node: Node3D = load(ENV + h[0] + ".gltf").instantiate()
		node.position = h[1]
		node.rotation.y = h[2]
		node.scale = Vector3.ONE * 6.5
		B.snowify(node, 0.5, 0.75)
		add_child(node)
		# Warm window glow spilling onto the snow in front of the house.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.62, 0.3)
		lamp.light_energy = 2.2
		lamp.omni_range = 7.0
		lamp.position = h[1] + Vector3(sin(h[2]), 0, cos(h[2])) * 4.2 + Vector3(0, 1.6, 0)
		add_child(lamp)

	var well: Node3D = load(ENV + "building_well_red.gltf").instantiate()
	well.position = Vector3(0, 0, -4)
	well.scale = Vector3.ONE * 5.0
	B.snowify(well, 0.5, 0.75)
	add_child(well)
	for p in [Vector3(4, 0, -1), Vector3(-6, 0, -7), Vector3(7, 0, -9)]:
		var prop: Node3D = load(ENV + ["barrel", "crate_A_big"][randi() % 2] + ".gltf").instantiate()
		prop.position = p
		prop.scale = Vector3.ONE * 5.0
		B.snowify(prop, 0.5, 0.75)
		add_child(prop)


func _make_snow() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 260 if low_end else 500
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = B.dot_texture()
	m.albedo_color = Color(1, 1, 1, 0.9)
	q.material = m
	p.mesh = q
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 2, 18)
	p.position = Vector3(0, 6, -12)
	p.direction = Vector3(0.3, -1, 0.1)
	p.spread = 15.0
	p.gravity = Vector3(0.4, -1.2, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	return p


## Forest and rocks appear in deterministic cells around the focus point.
func _update_cells() -> void:
	var cx := int(floor(focus.x / CELL))
	var cz := int(floor(focus.z / CELL))
	var keep := {}
	for x in range(cx - cell_radius, cx + cell_radius + 1):
		for z in range(cz - cell_radius, cz + cell_radius + 1):
			var key := Vector2i(x, z)
			keep[key] = true
			if not _cells.has(key):
				_cells[key] = _build_cell(key)
	for key in _cells.keys():
		if not keep.has(key):
			_cells[key].queue_free()
			_cells.erase(key)


func _build_cell(key: Vector2i) -> Node3D:
	var cell := Node3D.new()
	add_child(cell)
	_rng.seed = hash(key)
	var count := _rng.randi_range(1, 4)
	for i in count:
		var pos := Vector3((key.x + _rng.randf()) * CELL, 0, (key.y + _rng.randf()) * CELL)
		if pos.length() < VILLAGE_RADIUS:
			continue
		var idx := _rng.randi() % _scatter_scenes.size()
		var n: Node3D = _scatter_scenes[idx].instantiate()
		n.position = pos
		n.rotation.y = _rng.randf() * TAU
		var big := idx >= 2 and idx <= 3
		n.scale = Vector3.ONE * (_rng.randf_range(5.0, 7.5) if not big else _rng.randf_range(4.0, 5.5))
		B.snowify(n, 0.62, 0.7)
		cell.add_child(n)
	return cell
