extends "res://scripts/work/minigame.gd"
## Worker: taxi driver. Tap the left or right side to change lanes; pick up
## passengers waving on the road, dodge cones and other cars.

var _lane := 1
var _x := 0.0
var _speed := 520.0
var _items: Array = []
var _spawn := 0.5
var _road := 0.0
var _hurt := 0.0


func _lane_x(i: int) -> float:
	return size.x * (0.5 + (i - 1) * 0.26)


func setup() -> void:
	_x = 0.0


func step(delta: float) -> void:
	if _x == 0.0:
		_x = _lane_x(_lane)
	_x = lerpf(_x, _lane_x(_lane), 1.0 - exp(-16.0 * delta))
	_speed = minf(_speed + delta * 6.0, 950.0)
	_road = fmod(_road + _speed * delta, 140.0)
	_hurt = maxf(0.0, _hurt - delta)
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = randf_range(0.55, 1.0) * 520.0 / _speed
		var kind := "fare" if randf() < 0.42 else ("cone" if randf() < 0.5 else "car")
		_items.append({"lane": randi() % 3, "y": -120.0, "kind": kind, "hit": false})
	var car_y := size.y - 170.0
	for it in _items:
		it["y"] += _speed * delta
		if not it["hit"] and it["lane"] == _lane and absf(it["y"] - car_y) < 90.0:
			it["hit"] = true
			if it["kind"] == "fare":
				give(pay * 2.0, Vector2(_x, car_y - 120), "Пассажир!")
			elif _hurt <= 0.0:
				_hurt = 1.0
				_speed = maxf(420.0, _speed * 0.7)
				give(-pay * 3.0, Vector2(_x, car_y - 120), "Авария!")
	_items = _items.filter(func(it: Dictionary) -> bool: return it["y"] < size.y + 150.0 and not (it["hit"] and it["kind"] == "fare"))


func tap(at: Vector2) -> void:
	_lane = clampi(_lane + (-1 if at.x < size.x * 0.5 else 1), 0, 2)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#3f8f4a"))
	var road := Rect2(size.x * 0.11, 0, size.x * 0.78, size.y)
	draw_rect(road, Color("#3b3d47"))
	draw_rect(Rect2(road.position.x - 10, 0, 10, size.y), Color.WHITE)
	draw_rect(Rect2(road.end.x, 0, 10, size.y), Color.WHITE)
	for lx in [size.x * 0.37, size.x * 0.63]:
		var y := -140.0 + _road
		while y < size.y:
			draw_rect(Rect2(lx - 5, y, 10, 70), Color(1, 1, 1, 0.7))
			y += 140.0
	for it in _items:
		var c := Vector2(_lane_x(it["lane"]), it["y"])
		match it["kind"]:
			"fare":
				person(c + Vector2(0, 60), Color("#ff5fa2"), false, 0.0)
				draw_line(c + Vector2(20, -60), c + Vector2(44, -110), Color("#f2c19b"), 10)
				text("$", c + Vector2(0, -150), 44, GREEN, 900)
			"cone":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 40), c + Vector2(0, -50), c + Vector2(34, 40)]), Color("#ff7a1a"))
				draw_rect(Rect2(c + Vector2(-18, -6), Vector2(36, 14)), Color.WHITE)
			"car":
				_car(c, Color("#6b7dff"), false)
	if _hurt <= 0.0 or fmod(_hurt, 0.2) < 0.1:
		_car(Vector2(_x, size.y - 170.0), Color("#ffd447"), true)
	hint("Касайся слева или справа — перестраивайся. Бери пассажиров!")


## A car seen from above; the taxi has a checkered sign on its roof.
func _car(c: Vector2, col: Color, taxi: bool) -> void:
	rounded(Rect2(c - Vector2(52, 90), Vector2(104, 180)), col, 26)
	rounded(Rect2(c - Vector2(40, 50), Vector2(80, 44)), Color(0.1, 0.12, 0.2, 0.85), 10)
	rounded(Rect2(c - Vector2(40, -40), Vector2(80, 34)), Color(0.1, 0.12, 0.2, 0.85), 10)
	if taxi:
		for i in 4:
			draw_rect(Rect2(c + Vector2(-32 + i * 16, -6), Vector2(16, 12)), Color.BLACK if i % 2 == 0 else Color.WHITE)
