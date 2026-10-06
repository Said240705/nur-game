extends Node2D
## A mote of memory left by a released Faceless. Drifts to Nur when she is near.

signal collected(value: int)

var target: Node2D
var value := 1

var _t := randf() * TAU
var _vel := Vector2.ZERO
var _pop := Vector2.ZERO
var _attracted := false


func _ready() -> void:
	_pop = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)


func _process(delta: float) -> void:
	_t += delta
	position += _pop * delta * 3.0
	_pop = _pop.lerp(Vector2.ZERO, minf(1.0, delta * 5.0))
	var to: Vector2 = target.global_position + Vector2(0, -34) - global_position
	var d := to.length()
	if _attracted or d < target.pickup_radius:
		_attracted = true
		_vel = _vel.lerp(to.normalized() * 950.0, minf(1.0, delta * 6.0))
		position += _vel * delta
	if d < 26.0:
		collected.emit(value)
		Sfx.play("shard", -14.0, randf_range(0.95, 1.2))
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, sin(_t * 3.0) * 4.0 - 18.0)
	var size := 6.0 + value * 0.6
	var c := Color(1.0, 0.86, 0.6)
	draw_circle(bob, size * 2.6, Color(c, 0.12))
	draw_circle(bob, size * 1.5, Color(c, 0.25))
	var d := PackedVector2Array([bob + Vector2(0, -size), bob + Vector2(size * 0.65, 0), bob + Vector2(0, size), bob + Vector2(-size * 0.65, 0)])
	draw_colored_polygon(d, Color(1.0, 0.95, 0.85))
