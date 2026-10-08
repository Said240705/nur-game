extends "res://scripts/work/minigame.gd"
## Homeless: hand out flyers. Tap passers-by to give them one; never the
## policeman — handing out flyers here is not quite legal.

var _people: Array = []
var _spawn := 0.0


func setup() -> void:
	_spawn = 0.3


func step(delta: float) -> void:
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = randf_range(0.55, 1.1)
		var dir := 1.0 if randf() < 0.5 else -1.0
		var cop := randf() < 0.16
		var coats := [Color("#e07b39"), Color("#3d8bff"), Color("#b45cff"), Color("#2ee59d"), Color("#ff5fa2"), Color("#c9a26b")]
		_people.append({"x": -60.0 if dir > 0.0 else size.x + 60.0, "dir": dir, "speed": randf_range(150, 300),
			"row": randf(), "cop": cop, "coat": Color("#24315e") if cop else coats[randi() % coats.size()],
			"got": false, "phase": randf() * TAU})
	for p in _people:
		p["x"] += p["dir"] * p["speed"] * delta * (1.8 if p["got"] else 1.0)
		p["phase"] += delta * 10.0
	_people = _people.filter(func(p: Dictionary) -> bool: return p["x"] > -100.0 and p["x"] < size.x + 100.0)


func _feet(p: Dictionary) -> Vector2:
	return Vector2(p["x"], size.y * (0.62 + 0.22 * p["row"]))


func tap(at: Vector2) -> void:
	var best := {}
	var best_d := 140.0
	for p in _people:
		var f := _feet(p)
		var d := at.distance_to(f + Vector2(0, -80))
		if d < best_d and not p["got"]:
			best_d = d
			best = p
	if best.is_empty():
		return
	best["got"] = true
	var where := _feet(best) + Vector2(0, -200)
	if best["cop"]:
		best["speed"] = 70.0
		give(-pay * 4.0, where, "Штраф!")
	else:
		give(pay, where)


func _draw() -> void:
	# Evening street: sky, houses, lit windows, pavement.
	draw_rect(Rect2(Vector2.ZERO, size), Color("#20264d"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var x := 0.0
	while x < size.x:
		var w := rng.randf_range(140, 230)
		var h := rng.randf_range(size.y * 0.25, size.y * 0.45)
		draw_rect(Rect2(x, size.y * 0.5 - h, w - 8, h), Color("#2e2a52"))
		for wy in range(int(size.y * 0.5 - h) + 24, int(size.y * 0.5) - 30, 54):
			for wx in range(int(x) + 18, int(x + w) - 40, 48):
				if rng.randf() < 0.6:
					draw_rect(Rect2(wx, wy, 24, 30), Color("#ffd27a") if rng.randf() < 0.7 else Color("#3d3870"))
		x += w
	draw_rect(Rect2(0, size.y * 0.5, size.x, size.y * 0.5), Color("#3a3550"))
	draw_rect(Rect2(0, size.y * 0.5, size.x, 14), Color("#57507a"))
	var sorted := _people.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["row"] < b["row"])
	for p in sorted:
		var f := _feet(p)
		person(f, p["coat"], true, p["phase"], Color("#111a3a") if p["cop"] else Color(0, 0, 0, 0))
		if p["got"]:
			draw_rect(Rect2(f + Vector2(-14 + p["dir"] * 26, -120), Vector2(28, 36)), Color.WHITE)
			if p["cop"]:
				text("!", f + Vector2(0, -190), 60, RED, 900)
	hint("Касайся прохожих — раздавай листовки. Полицию не трогай!")
