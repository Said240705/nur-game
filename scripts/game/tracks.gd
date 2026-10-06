extends MultiMeshInstance3D
## Footprints pressed into the snow that slowly fill in behind Nur.

const LIFE := 7.0
const MAX_PRINTS := 160

var _ages := PackedFloat32Array()
var _next := 0


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.26)
	q.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.42, 0.5, 0.7)
	m.roughness = 1.0
	m.albedo_texture = preload("res://scripts/world/builders.gd").dot_texture()
	q.material = m
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = q
	multimesh.instance_count = MAX_PRINTS
	_ages.resize(MAX_PRINTS)
	for i in MAX_PRINTS:
		_ages[i] = LIFE
		multimesh.set_instance_color(i, Color(1, 1, 1, 0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add(pos: Vector3, yaw: float) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 0.02, pos.z))
	multimesh.set_instance_transform(_next, t)
	_ages[_next] = 0.0
	_next = (_next + 1) % MAX_PRINTS


func _process(delta: float) -> void:
	for i in MAX_PRINTS:
		if _ages[i] < LIFE:
			_ages[i] += delta
			multimesh.set_instance_color(i, Color(1, 1, 1, 0.55 * (1.0 - _ages[i] / LIFE)))
