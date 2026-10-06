extends Node3D
## A Faceless: someone the valley has forgotten. Pale, slow, drawn to warmth.
## When released by Nur's light it dissolves upward and leaves memory motes behind.

signal died(enemy: Node3D, value: int)

enum Kind { WISP, TALL, KEEPER }

const B := preload("res://scripts/world/builders.gd")
const GHOST := preload("res://shaders/ghost.gdshader")

static var _mesh: ArrayMesh

var kind := Kind.WISP
var target: Node3D
var hp := 2.0
var speed := 1.7
var radius := 0.45
var drain := 12.0
var value := 1
var alive := true

var _mat: ShaderMaterial
var _flash := 0.0
var _knock := Vector3.ZERO
var _dying := 0.0
var _appear := 0.0
var _bob := randf() * TAU


func _ready() -> void:
	if _mesh == null:
		_mesh = B.ghost_mesh()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = GHOST
	_mat.set_shader_parameter("phase", randf() * TAU)
	mi.material_override = _mat
	add_child(mi)


func setup(k: Kind, tgt: Node3D, elapsed: float) -> void:
	kind = k
	target = tgt
	var s := 1.0
	match k:
		Kind.WISP:
			hp = 2.0 + elapsed * 0.012
			speed = randf_range(1.5, 2.0)
			radius = 0.45
			drain = 12.0
			value = 1
			s = randf_range(0.9, 1.05)
		Kind.TALL:
			hp = 6.0 + elapsed * 0.03
			speed = randf_range(1.1, 1.4)
			radius = 0.6
			drain = 18.0
			value = 3
			s = 1.45
		Kind.KEEPER:
			hp = 40.0 + elapsed * 0.15
			speed = 0.9
			radius = 1.1
			drain = 30.0
			value = 12
			s = 2.4
	scale = Vector3.ONE * s


func hit(damage: float, from := Vector3.INF) -> void:
	if not alive:
		return
	hp -= damage
	_flash = 0.18
	if from != Vector3.INF:
		var away := global_position - from
		away.y = 0.0
		_knock += away.normalized() * (5.0 / scale.x)
	if hp <= 0.0:
		alive = false
		died.emit(self, value)
		Sfx.play("fade", -18.0, randf_range(0.8, 1.2))


func _process(delta: float) -> void:
	_appear = minf(1.0, _appear + delta * 0.5)
	_flash = maxf(0.0, _flash - delta)
	_mat.set_shader_parameter("flash", _flash / 0.18)
	if not alive:
		_dying += delta
		position.y += 1.2 * delta
		_mat.set_shader_parameter("dissolve", _dying)
		_mat.set_shader_parameter("appear", 1.0 - _dying)
		if _dying > 1.0:
			queue_free()
		return
	_mat.set_shader_parameter("appear", _appear)
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > 0.05:
		position += to.normalized() * speed * delta
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, delta * 3.0))
	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	_bob += delta
	position.y = 0.08 + sin(_bob * 1.4) * 0.06
