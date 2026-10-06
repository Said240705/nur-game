extends Node3D
## A mote of memory left by a released Faceless. Drifts to Nur when she is near.

signal collected(value: int)

const B := preload("res://scripts/world/builders.gd")

static var _mesh: Mesh
static var _mat: Material

var target: Node3D
var value := 1

var _t := randf() * TAU
var _vel := Vector3.ZERO
var _pop := Vector3.ZERO
var _attracted := false
var _gem: MeshInstance3D


func _ready() -> void:
	if _mesh == null:
		var s := SphereMesh.new()
		s.radial_segments = 4
		s.rings = 2
		s.radius = 0.13
		s.height = 0.34
		_mesh = s
		_mat = B.emissive(Color(1.0, 0.82, 0.55), 5.0)
	_gem = MeshInstance3D.new()
	_gem.mesh = _mesh
	_gem.material_override = _mat
	_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gem.scale = Vector3.ONE * (1.0 + value * 0.08)
	add_child(_gem)
	var a := randf() * TAU
	_pop = Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 2.4)


func _process(delta: float) -> void:
	_t += delta
	position += _pop * delta * 3.0
	_pop = _pop.lerp(Vector3.ZERO, minf(1.0, delta * 5.0))
	_gem.position.y = 0.9 + sin(_t * 3.0) * 0.12
	_gem.rotation.y += delta * 2.5
	var to: Vector3 = target.global_position + Vector3(0, 0.1, 0) - global_position
	to.y = 0.0
	var d := to.length()
	if _attracted or d < target.pickup_radius:
		_attracted = true
		_vel = _vel.lerp(to.normalized() * 18.0, minf(1.0, delta * 6.0))
		position += _vel * delta
	if d < 0.5:
		collected.emit(value)
		Sfx.play("shard", -14.0, randf_range(0.95, 1.2))
		queue_free()
