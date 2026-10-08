extends "res://scripts/work/minigame.gd"
## Student: courier. The parcel's label matches one front door; tap that house.
## Quick deliveries earn tips; the wrong door costs a little.

const DOORS := [Color("#ff5c6c"), Color("#3ee08f"), Color("#33c8ff"), Color("#ffd447")]
const TIME := 3.0

var _houses: Array = []
var _target := 0
var _left := TIME
var _flash := 0.0


func setup() -> void:
	_new_order()


func _new_order() -> void:
	var colors := DOORS.duplicate()
	colors.shuffle()
	_houses = colors.slice(0, 3)
	_target = randi() % 3
	_left = TIME


func step(delta: float) -> void:
	_left -= delta
	_flash = maxf(0.0, _flash - delta)
	if _left <= 0.0:
		give(0.0, Vector2(size.x * 0.5, size.y * 0.7), "Клиент отменил заказ")
		_new_order()


func _house_rect(i: int) -> Rect2:
	var w := size.x / 3.0
	return Rect2(i * w + 16, size.y * 0.12, w - 32, size.y * 0.5)


func tap(at: Vector2) -> void:
	for i in 3:
		if _house_rect(i).grow(10).has_point(at):
			var where := _house_rect(i).get_center() + Vector2(0, -60)
			if i == _target:
				give(pay * (1.0 + _left / TIME), where, "Доставлено!" if _left > TIME * 0.5 else "")
			else:
				give(-pay * 0.5, where, "Не тот адрес")
				_flash = 0.3
			_new_order()
			return


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#7ec8e3"))
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color("#8d8f9a"))
	for i in 3:
		var r := _house_rect(i)
		var walls: Color = [Color("#f4e1c1"), Color("#e8c9a0"), Color("#d9e4f0")][i]
		draw_rect(r, walls)
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(-16, 0), r.position + Vector2(r.size.x * 0.5, -r.size.y * 0.3),
			r.position + Vector2(r.size.x + 16, 0)]), Color("#a14a3b"))
		draw_rect(Rect2(r.position + Vector2(24, 30), Vector2(70, 60)), Color("#5b7fa6"))
		draw_rect(Rect2(r.end - Vector2(94, r.size.y - 30), Vector2(70, 60)), Color("#5b7fa6"))
		var door := Rect2(r.get_center().x - 45, r.end.y - 150, 90, 150)
		rounded(door, _houses[i], 14)
		draw_circle(door.position + Vector2(70, 80), 7, Color(0, 0, 0, 0.4))
	# The parcel with a coloured label, and the time left.
	var box := Rect2(size.x * 0.5 - 110, size.y * 0.7, 220, 170)
	rounded(box, Color("#c8935a"), 14)
	draw_rect(Rect2(box.position + Vector2(100, 0), Vector2(20, box.size.y)), Color("#a87545"))
	rounded(Rect2(box.position + Vector2(40, 50), Vector2(140, 70)), _houses[_target], 10, Color.WHITE, 4)
	var k := clampf(_left / TIME, 0.0, 1.0)
	rounded(Rect2(size.x * 0.15, size.y - 50, size.x * 0.7, 20), Color(0, 0, 0, 0.25), 10)
	rounded(Rect2(size.x * 0.15, size.y - 50, size.x * 0.7 * k, 20), GREEN.lerp(RED, 1.0 - k), 10)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0, 0, _flash))
	hint("Отнеси посылку в дом с дверью того же цвета")
