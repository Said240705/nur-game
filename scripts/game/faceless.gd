extends Node2D
## A Faceless: someone the valley has forgotten. Pale, slow, drawn to warmth.
## When released by Nur's light it rises and leaves a memory mote behind.

signal died(enemy: Node2D, value: int)

enum Kind { WISP, TALL, KEEPER }

var kind := Kind.WISP
var target: Node2D
var hp := 2.0
var speed := 70.0
var radius := 20.0
var drain := 12.0
var value := 1
var alive := true

var _t := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _dying := 0.0
var _appear := 0.0
var _h := 1.0


func _ready() -> void:
	# Faceless glow faintly on their own, so they read as pale shapes in the dark.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func setup(k: Kind, tgt: Node2D, elapsed: float) -> void:
	kind = k
	target = tgt
	_t = randf() * 10.0
	match k:
		Kind.WISP:
			hp = 2.0 + elapsed * 0.012
			speed = randf_range(60.0, 85.0)
			radius = 20.0
			drain = 12.0
			value = 1
			_h = randf_range(0.9, 1.1)
		Kind.TALL:
			hp = 6.0 + elapsed * 0.03
			speed = randf_range(45.0, 60.0)
			radius = 26.0
			drain = 18.0
			value = 3
			_h = 1.45
		Kind.KEEPER:
			hp = 40.0 + elapsed * 0.15
			speed = 38.0
			radius = 46.0
			drain = 30.0
			value = 12
			_h = 2.4


func hit(damage: float, from := Vector2.INF) -> void:
	if not alive:
		return
	hp -= damage
	_flash = 0.15
	if from != Vector2.INF:
		_knock += (global_position - from).normalized() * (240.0 / _h)
	if hp <= 0.0:
		alive = false
		died.emit(self, value)
		Sfx.play("fade", -18.0, randf_range(0.8, 1.2))


func _process(delta: float) -> void:
	_t += delta
	_appear = minf(1.0, _appear + delta * 0.6)
	_flash = maxf(0.0, _flash - delta)
	if not alive:
		_dying += delta
		position.y -= 50.0 * delta
		if _dying > 1.0:
			queue_free()
		queue_redraw()
		return
	var to := target.global_position - global_position
	if to.length() > 1.0:
		position += to.normalized() * speed * delta
	position += _knock * delta
	_knock = _knock.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
	queue_redraw()


func _draw() -> void:
	var fade := _appear * (1.0 - clampf(_dying, 0.0, 1.0))
	var s := _h * (1.0 + _dying * 0.3)
	var sway := sin(_t * 1.7) * 5.0
	var body := Color(0.62, 0.66, 0.74, 0.55 * fade)
	if _flash > 0.0:
		body = Color(1.0, 0.86, 0.66, fade)

	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0 * s, Color(0, 0, 0, 0.22 * fade))
	draw_set_transform(Vector2.ZERO)

	# Taller points lean further with the sway, so the figure bends like smoke.
	var shape := [
		Vector2(-11, -60), Vector2(11, -60), Vector2(18, -30), Vector2(16, -6),
		Vector2(10, 0), Vector2(5, -7), Vector2(0, 2), Vector2(-5, -7),
		Vector2(-10, 0), Vector2(-16, -6), Vector2(-18, -30),
	]
	var pts := PackedVector2Array()
	for p: Vector2 in shape:
		var k := -p.y / 60.0
		var wisp := sin(_t * 5.0 + p.x) * 2.0 if p.y > -8.0 else 0.0
		pts.append(Vector2(p.x + sway * k + wisp, p.y) * s)
	draw_colored_polygon(pts, body)

	var head := Vector2(sway, -73) * s
	draw_set_transform(head, 0.0, Vector2(1.0, 1.25))
	draw_circle(Vector2.ZERO, 11.5 * s, body)
	# The blank face: no eyes, no mouth, just a slightly hollow oval.
	draw_circle(Vector2(0, 1.5 * s), 7.5 * s, Color(0.4, 0.43, 0.5, 0.7 * fade))
	draw_set_transform(Vector2.ZERO)

	if not alive:
		var rng := RandomNumberGenerator.new()
		rng.seed = get_instance_id()
		for i in 10:
			var p := Vector2(rng.randf_range(-20, 20), rng.randf_range(-80, 0)) * s
			p.y -= _dying * rng.randf_range(30, 90)
			draw_circle(p, rng.randf_range(1.5, 3.5), Color(1, 0.9, 0.75, (1.0 - _dying) * 0.9))
