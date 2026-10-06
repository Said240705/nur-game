extends Node2D
## Nur: a dark silhouette carrying the only warm light in the world.
## Her light is both her health and her weapon: it pulses outward on its own,
## and it shrinks when the Faceless touch her.

signal pulsed(origin: Vector2, radius: float, damage: float)

const Fx := preload("res://scripts/fx.gd")
const BODY := Color(0.07, 0.07, 0.09)
const GLOW := Color(1.0, 0.66, 0.36)
const RING_LIFE := 0.6
const SPARK_ORBIT := 120.0

var tracks: Node2D
## Joystick direction, set by the game every frame (length <= 1).
var move_input := Vector2.ZERO

var max_light := 100.0
var light := 100.0
var regen := 2.5
var speed := 320.0
var pulse_interval := 1.5
var pulse_radius := 250.0
var pulse_damage := 1.0
var pickup_radius := 150.0
var sparks := 0
var spark_damage := 5.0

var _vel := Vector2.ZERO
var _t := 0.0
var _pulse_t := 0.0
var _rings: Array[float] = []
var _step_acc := 0.0
var _step_side := 1.0
var _hurt := 0.0
var _out := false
var _out_t := 0.0
var _lamp: PointLight2D


func _ready() -> void:
	_lamp = PointLight2D.new()
	_lamp.texture = Fx.radial_texture(256)
	_lamp.color = GLOW
	_lamp.energy = 1.15
	_lamp.position = Vector2(0, -36)
	add_child(_lamp)


func light_ratio() -> float:
	return clampf(light / max_light, 0.0, 1.0)


func drain(amount: float) -> void:
	if _out:
		return
	light = maxf(0.0, light - amount)
	_hurt = 0.2


## Called once the light hits zero: the lamp dies out over a couple of seconds.
func extinguish() -> void:
	_out = true


func spark_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in sparks:
		var a := _t * 2.4 + TAU * i / sparks
		out.append(global_position + Vector2(0, -30) + Vector2.from_angle(a) * SPARK_ORBIT)
	return out


func _process(delta: float) -> void:
	_t += delta
	if _out:
		_out_t += delta
		_lamp.energy = maxf(0.0, 0.8 - _out_t * 0.5)
		queue_redraw()
		return

	var input := move_input + _keyboard()
	input = input.limit_length(1.0)
	_vel = _vel.lerp(input * speed, minf(1.0, delta * 10.0))
	position += _vel * delta

	light = minf(max_light, light + regen * delta)
	_hurt = maxf(0.0, _hurt - delta)

	var r := light_ratio()
	var breath := 1.0 + 0.04 * sin(_t * 2.6)
	_lamp.texture_scale = (2.0 + pulse_radius / 250.0 * 0.5) * lerpf(0.5, 1.0, r) * breath
	_lamp.energy = lerpf(0.7, 1.15, r)

	_pulse_t += delta
	if _pulse_t >= pulse_interval:
		_pulse_t = 0.0
		_rings.append(0.0)
		pulsed.emit(global_position, pulse_radius, pulse_damage)
		Sfx.play("pulse", -15.0, randf_range(0.95, 1.05))
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i] += delta
		if _rings[i] > RING_LIFE:
			_rings.remove_at(i)

	var moving := _vel.length()
	if moving > 40.0 and tracks:
		_step_acc += moving * delta
		if _step_acc > 36.0:
			_step_acc = 0.0
			_step_side = -_step_side
			var side := _vel.orthogonal().normalized() * 7.0 * _step_side
			tracks.add(global_position + side, _vel.angle())
	queue_redraw()


func _keyboard() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	return v


func _draw() -> void:
	var r := light_ratio()
	if _out:
		r *= maxf(0.0, 1.0 - _out_t * 0.6)

	for age in _rings:
		var k := age / RING_LIFE
		var rad := pulse_radius * (1.0 - pow(1.0 - k, 3.0))
		draw_arc(Vector2(0, -24), rad, 0.0, TAU, 72, Color(GLOW, (1.0 - k) * 0.5), 2.0 + 6.0 * (1.0 - k), true)

	# Shadow on the snow.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)

	var lean := clampf(_vel.x / speed, -1.0, 1.0) * 6.0
	var sway := sin(_t * 7.0) * clampf(_vel.length() / speed, 0.0, 1.0) * 3.0
	var body := BODY.lerp(Color(0.9, 0.9, 0.95), _hurt * 2.0)
	var cloak := PackedVector2Array([
		Vector2(-8 + lean * 0.4, -50), Vector2(8 + lean * 0.4, -50),
		Vector2(15, -30), Vector2(21 - lean * 0.6 + sway, 0),
		Vector2(7, -3), Vector2(-7, -3),
		Vector2(-21 - lean * 0.6 + sway, 0), Vector2(-15, -30),
	])
	draw_colored_polygon(cloak, body)
	draw_circle(Vector2(lean * 0.6, -60), 11.5, body)
	# Scarf tail fluttering behind her.
	var tail := Vector2(-_vel.x, -_vel.y).limit_length(1.0) * 18.0 if _vel.length() > 20.0 else Vector2(-10, 6)
	draw_line(Vector2(lean * 0.5, -50), Vector2(lean * 0.5, -50) + tail + Vector2(0, sin(_t * 9.0) * 3.0), body, 4.0, true)

	var core := Vector2(lean * 0.4, -34)
	var beat := 0.8 + 0.2 * sin(_t * 4.0)
	for i in 4:
		draw_circle(core, 4.0 + i * 6.0, Color(GLOW, 0.22 * r * beat / (i + 1)))
	draw_circle(core, 3.5, Color(1.0, 0.88, 0.65, r))

	for p in spark_positions():
		var lp := p - global_position
		draw_circle(lp, 14.0, Color(GLOW, 0.15))
		draw_circle(lp, 7.0, Color(GLOW, 0.4))
		draw_circle(lp, 3.0, Color(1.0, 0.95, 0.8))
