extends Node3D
## Nur: a girl in a dark cloak carrying the only warm light in the valley.
## Her light is both her health and her weapon: it pulses outward on its own,
## and it shrinks when the Faceless touch her.

signal pulsed(origin: Vector3, radius: float, damage: float)

const B := preload("res://scripts/world/builders.gd")
const MODEL := preload("res://assets/characters/nur_temp.glb")
const TEXTURE := preload("res://assets/characters/nur_texture.png")
const GLOW := Color(1.0, 0.62, 0.3)
const RING_LIFE := 0.7
const SPARK_ORBIT := 2.6
const HIDDEN_PARTS := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]

var tracks: Node3D
## Movement wish on the ground plane (length <= 1), set by the game every frame.
var move_input := Vector2.ZERO

var max_light := 100.0
var light := 100.0
var regen := 2.5
var speed := 4.6
var pulse_interval := 1.5
var pulse_radius := 5.5
var pulse_damage := 1.0
var pickup_radius := 3.2
var sparks := 0
var spark_damage := 5.0

var _vel := Vector3.ZERO
var _t := 0.0
var _pulse_t := 0.0
var _step_acc := 0.0
var _step_side := 1.0
var _hurt := 0.0
var _out := false
var _out_t := 0.0
var _model: Node3D
var _anim: AnimationPlayer
var _lamp: OmniLight3D
var _ember: MeshInstance3D
var _spark_nodes: Array[MeshInstance3D] = []
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * 0.75
	add_child(_model)
	for part in HIDDEN_PARTS:
		var n := _model.find_child(part, true, false)
		if n:
			n.visible = false
	var skin := StandardMaterial3D.new()
	skin.albedo_texture = TEXTURE
	skin.roughness = 0.85
	for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		m.material_override = skin

	_anim = _model.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walking_A", "Running_A", "Sit_Floor_Idle", "Unarmed_Idle"]:
		if _anim.has_animation(a):
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_anim.play("Idle")

	_lamp = OmniLight3D.new()
	_lamp.light_color = GLOW
	_lamp.light_energy = 2.4
	_lamp.omni_range = 8.0
	_lamp.omni_attenuation = 1.2
	_lamp.position = Vector3(0, 1.3, 0.3)
	add_child(_lamp)

	_ember = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	_ember.mesh = s
	_ember.material_override = B.emissive(Color(1.0, 0.75, 0.45), 6.0)
	_ember.position = Vector3(0, 0.95, 0.22)
	add_child(_ember)

	_ring_mat = B.emissive(Color(1.0, 0.6, 0.28, 0.8), 3.0, true)
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func light_ratio() -> float:
	return clampf(light / max_light, 0.0, 1.0)


func drain(amount: float) -> void:
	if _out:
		return
	light = maxf(0.0, light - amount)
	_hurt = 0.25


## Called once the light hits zero: she falls and the lamp dies out.
func extinguish() -> void:
	_out = true
	_anim.play("Death_A")


## Sit down in the snow, as in the scene where she understands the truth.
func sit() -> void:
	_anim.play("Sit_Floor_Down")
	_anim.queue("Sit_Floor_Idle")


func spark_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in sparks:
		var a := _t * 2.2 + TAU * i / sparks
		out.append(global_position + Vector3(cos(a) * SPARK_ORBIT, 1.0, sin(a) * SPARK_ORBIT))
	return out


func _process(delta: float) -> void:
	_t += delta
	if _out:
		_out_t += delta
		_lamp.light_energy = maxf(0.0, 2.4 - _out_t * 1.2)
		_ember.visible = _out_t < 1.5
		return

	var wish := Vector3(move_input.x, 0, move_input.y) + _keyboard()
	wish = wish.limit_length(1.0)
	_vel = _vel.lerp(wish * speed, minf(1.0, delta * 9.0))
	position += _vel * delta

	var moving := Vector2(_vel.x, _vel.z).length()
	if moving > 0.3:
		var target_yaw := atan2(_vel.x, _vel.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 10.0))
	var want_anim := "Idle"
	if moving > speed * 0.6:
		want_anim = "Running_A"
	elif moving > 0.4:
		want_anim = "Walking_A"
	if _anim.current_animation != want_anim:
		_anim.play(want_anim, 0.25)
	_anim.speed_scale = clampf(moving / (speed * 0.8), 0.8, 1.3) if want_anim != "Idle" else 1.0

	light = minf(max_light, light + regen * delta)
	_hurt = maxf(0.0, _hurt - delta)
	var r := light_ratio()
	var breath := 1.0 + 0.05 * sin(_t * 2.4)
	_lamp.omni_range = (6.0 + pulse_radius * 0.5) * lerpf(0.55, 1.0, r) * breath
	_lamp.light_energy = lerpf(1.2, 2.6, r) * (1.0 - _hurt)
	(_ember.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(2.0, 7.0, r) * breath

	_pulse_t += delta
	if _pulse_t >= pulse_interval:
		_pulse_t = 0.0
		_spawn_ring()
		pulsed.emit(global_position, pulse_radius, pulse_damage)
		Sfx.play("pulse", -15.0, randf_range(0.95, 1.05))

	_update_sparks()

	if moving > 0.8 and tracks:
		_step_acc += moving * delta
		if _step_acc > 0.55:
			_step_acc = 0.0
			_step_side = -_step_side
			var side := Vector3(_vel.z, 0, -_vel.x).normalized() * 0.13 * _step_side
			tracks.add(global_position + side, rotation.y)


func _keyboard() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.z += 1
	return v


## A flat ring of light that sweeps outward over the snow.
func _spawn_ring() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	var mat := _ring_mat.duplicate() as StandardMaterial3D
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.15, 0)
	ring.scale = Vector3(0.3, 0.2, 0.3)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(pulse_radius, 0.2, pulse_radius), RING_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, RING_LIFE)
	tw.chain().tween_callback(ring.queue_free)


func _update_sparks() -> void:
	while _spark_nodes.size() < sparks:
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.12
		m.height = 0.24
		s.mesh = m
		s.material_override = B.emissive(Color(1.0, 0.7, 0.4), 6.0)
		get_parent().add_child(s)
		_spark_nodes.append(s)
	var pos := spark_positions()
	for i in _spark_nodes.size():
		_spark_nodes[i].global_position = pos[i] + Vector3(0, sin(_t * 4.0 + i) * 0.15, 0)
