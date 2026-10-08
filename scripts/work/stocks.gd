extends "res://scripts/work/minigame.gd"
## Oligarch and billionaire: trade. The price moves live; buy low, sell high.
## The profit is the move in percent times your stake.

var _prices: Array[float] = []
var _price := 100.0
var _trend := 0.0
var _tick := 0.0
var _bought := -1.0


func setup() -> void:
	for i in 90:
		_advance()


func _advance() -> void:
	if randf() < 0.04:
		_trend = randf_range(-0.9, 0.9)
	_trend *= 0.97
	_price = maxf(20.0, _price * (1.0 + (_trend + randf_range(-1.0, 1.0)) * 0.012))
	_prices.append(_price)
	if _prices.size() > 90:
		_prices.pop_front()


func step(delta: float) -> void:
	_tick += delta
	while _tick >= 0.1:
		_tick -= 0.1
		_advance()


func _button() -> Rect2:
	return Rect2(size.x * 0.1, size.y - 190, size.x * 0.8, 150)


func _profit() -> float:
	return pay * 25.0 * (_price - _bought) / _bought


func tap(at: Vector2) -> void:
	if not _button().has_point(at):
		return
	if _bought < 0.0:
		_bought = _price
		give(0.0, _button().get_center() + Vector2(0, -120), "Купил по %.1f" % _price)
	else:
		var p := _profit()
		give(p, _button().get_center() + Vector2(0, -120), "Продал по %.1f" % _price)
		_bought = -1.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0f1220"))
	var chart := Rect2(40, 90, size.x - 80, size.y - 330)
	for i in 5:
		var gy := chart.position.y + i * chart.size.y / 4.0
		draw_line(Vector2(chart.position.x, gy), Vector2(chart.end.x, gy), Color(1, 1, 1, 0.06), 2)
	var lo: float = _prices.min()
	var hi: float = _prices.max()
	var span := maxf(hi - lo, 1.0)
	var pts := PackedVector2Array()
	for i in _prices.size():
		pts.append(Vector2(chart.position.x + i * chart.size.x / 89.0, chart.end.y - (_prices[i] - lo) / span * chart.size.y))
	var up := _prices[-1] >= _prices[0]
	var col := GREEN if up else RED
	var fill := pts.duplicate()
	fill.append(Vector2(chart.end.x, chart.end.y))
	fill.append(Vector2(chart.position.x, chart.end.y))
	draw_colored_polygon(fill, Color(col, 0.12))
	draw_polyline(pts, col, 5, true)
	draw_circle(pts[-1], 12, col)
	if _bought > 0.0:
		var by := chart.end.y - (_bought - lo) / span * chart.size.y
		draw_dashed_line(Vector2(chart.position.x, by), Vector2(chart.end.x, by), Color(1, 1, 1, 0.5), 3, 14)
		var p := _profit()
		text(("+" if p >= 0.0 else "") + "%s" % _money(p), Vector2(size.x * 0.5, chart.end.y + 50), 52, GREEN if p >= 0.0 else RED, 900)
	text("Цена %.1f" % _price, Vector2(size.x * 0.5, 50), 40, Color.WHITE, 800)
	var b := _button()
	rounded(b, GREEN if _bought < 0.0 else Color("#ff5fa2"), 75)
	text("Купить" if _bought < 0.0 else "Продать", b.get_center(), 54, Color("#0b1a14"), 900)


func _money(v: float) -> String:
	return preload("res://scripts/game/data.gd").money(v)
