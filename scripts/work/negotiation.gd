extends "res://scripts/work/minigame.gd"
## Entrepreneur and millionaire: negotiate. The needle swings across the
## client's mood; stop it in the green to close a big deal. Each success
## narrows the green and speeds the needle up; a miss resets it.

var title := "Клиент готов заплатить"
var _pos := 0.0
var _dir := 1.0
var _speed := 0.7
var _center := 0.5
var _green := 0.14
var _streak := 0
var _cool := 0.0


func setup() -> void:
	_new_round()


func _new_round() -> void:
	_center = randf_range(0.2, 0.8)
	_green = maxf(0.05, 0.14 - _streak * 0.012)
	_speed = minf(0.7 + _streak * 0.08, 1.8)


func step(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	_pos += _dir * _speed * delta
	if _pos > 1.0:
		_pos = 1.0
		_dir = -1.0
	elif _pos < 0.0:
		_pos = 0.0
		_dir = 1.0


func _zone() -> int:
	var d := absf(_pos - _center)
	if d < _green * 0.5:
		return 2
	if d < _green * 1.6:
		return 1
	return 0


func tap(_at: Vector2) -> void:
	if _cool > 0.0:
		return
	_cool = 0.25
	var where := Vector2(size.x * 0.5, size.y * 0.42)
	match _zone():
		2:
			_streak += 1
			give(pay * (3.0 + _streak * 0.5), where, "Сделка! Серия ×%d" % _streak if _streak > 1 else "Сделка!")
		1:
			give(pay, where, "Неплохо")
		0:
			_streak = 0
			give(0.0, where, "Клиент ушёл")
	_new_round()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1d2033"))
	# The client: a face whose mood follows the needle.
	var face := Vector2(size.x * 0.5, size.y * 0.3)
	var mood := _zone()
	draw_circle(face, 120, Color("#f2c19b"))
	rounded(Rect2(face + Vector2(-150, 120), Vector2(300, 200)), Color("#3d4466"), 60)
	draw_circle(face + Vector2(-40, -20), 12, Color("#2b2d42"))
	draw_circle(face + Vector2(40, -20), 12, Color("#2b2d42"))
	var curve: float = [-0.6, 0.0, 0.7][mood]
	var pts := PackedVector2Array()
	for i in 9:
		var x := -50.0 + i * 12.5
		pts.append(face + Vector2(x, 50 - curve * 30 * (1.0 - pow(x / 50.0, 2))))
	draw_polyline(pts, Color("#8a3b3b"), 8, true)
	# The mood bar.
	var bar := Rect2(size.x * 0.08, size.y * 0.66, size.x * 0.84, 80)
	rounded(bar, RED.darkened(0.2), 30)
	var y_w := _green * 3.2 * bar.size.x
	rounded(Rect2(bar.position.x + _center * bar.size.x - y_w * 0.5, bar.position.y, y_w, bar.size.y), Color("#ffb347"), 30)
	var g_w := _green * bar.size.x
	rounded(Rect2(bar.position.x + _center * bar.size.x - g_w * 0.5, bar.position.y, g_w, bar.size.y), GREEN, 30)
	var nx := bar.position.x + _pos * bar.size.x
	draw_line(Vector2(nx, bar.position.y - 30), Vector2(nx, bar.end.y + 30), Color.WHITE, 10)
	draw_circle(Vector2(nx, bar.position.y - 30), 14, Color.WHITE)
	text(title, Vector2(size.x * 0.5, 40), 34, Color(1, 1, 1, 0.85), 700)
	text("Останови стрелку на зелёном", Vector2(size.x * 0.5, bar.end.y + 90), 34, Color(1, 1, 1, 0.6), 600)
	if _streak > 1:
		text("Серия ×%d" % _streak, Vector2(size.x * 0.5, bar.position.y - 80), 44, Color("#ffd447"), 900)
