extends RefCounted
## Little white pictograms on glossy coloured tiles, one per business and
## property, drawn from lines and shapes so they stay crisp at any size.

const W := Color(1, 1, 1, 0.96)


## A tile with the pictogram for `id`, filling `r` on `c`.
static func tile(c: CanvasItem, id: String, r: Rect2, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(r.size.x * 0.26))
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)
	# A soft shine across the top half.
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(1, 1, 1, 0.16)
	shine.set_corner_radius_all(int(r.size.x * 0.26))
	shine.corner_radius_bottom_left = int(r.size.x * 0.5)
	shine.corner_radius_bottom_right = int(r.size.x * 0.5)
	c.draw_style_box(shine, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)))
	glyph(c, id, r.get_center(), r.size.x / 100.0)


## Draws the pictogram centred at `m`, designed on a 100×100 grid scaled by `s`.
static func glyph(c: CanvasItem, id: String, m: Vector2, s: float) -> void:
	var p := func(x: float, y: float) -> Vector2: return m + Vector2(x, y) * s
	var line := func(a: Vector2, b: Vector2, w: float) -> void: c.draw_line(a, b, W, w * s, true)
	match id:
		"shawarma":
			c.draw_colored_polygon(PackedVector2Array([p.call(-30, 26), p.call(18, -30), p.call(32, -18), p.call(-18, 36)]), W)
			c.draw_circle(p.call(25, -24), 9 * s, W)
			for i in 3:
				line.call(p.call(-18 + i * 12, 22 - i * 14), p.call(-8 + i * 12, 30 - i * 14), 3)
		"wash":
			_car(c, p, 0.0)
			for i in 3:
				c.draw_circle(p.call(-22 + i * 22, -34), 6 * s, W)
		"coffee":
			c.draw_rect(Rect2(p.call(-26, -8), Vector2(44, 40) * s), W)
			c.draw_arc(p.call(22, 10), 12 * s, -PI * 0.5, PI * 0.5, 12, W, 6 * s, true)
			for i in 3:
				line.call(p.call(-16 + i * 12, -16), p.call(-12 + i * 12, -34), 4)
		"clothes":
			c.draw_colored_polygon(PackedVector2Array([p.call(-14, -32), p.call(-38, -18), p.call(-30, -2), p.call(-20, -6), p.call(-20, 34),
				p.call(20, 34), p.call(20, -6), p.call(30, -2), p.call(38, -18), p.call(14, -32), p.call(0, -22)]), W)
		"restaurant":
			c.draw_arc(p.call(0, 4), 26 * s, 0, TAU, 32, W, 6 * s, true)
			line.call(p.call(-40, -28), p.call(-40, 34), 5)
			line.call(p.call(40, -28), p.call(40, 34), 5)
			line.call(p.call(-46, -28), p.call(-46, -10), 3)
			line.call(p.call(-34, -28), p.call(-34, -10), 3)
		"gym":
			line.call(p.call(-30, 0), p.call(30, 0), 8)
			for sx in [-1.0, 1.0]:
				c.draw_rect(Rect2(p.call(sx * 30 - 8, -22), Vector2(16, 44) * s), W)
				c.draw_rect(Rect2(p.call(sx * 42 - 5, -14), Vector2(10, 28) * s), W)
		"hotel", "flat", "penthouse":
			var h := 70.0 if id == "flat" else 80.0
			var w := 50.0 if id == "penthouse" else 60.0
			c.draw_rect(Rect2(p.call(-w * 0.5, 40 - h), Vector2(w, h) * s), W)
			for row in 4:
				for col in 3:
					c.draw_rect(Rect2(p.call(-w * 0.5 + 8 + col * (w - 16) / 3.0, 48 - h + row * 16), Vector2(8, 8) * s), Color(0, 0, 0, 0.35))
			if id == "penthouse":
				c.draw_colored_polygon(PackedVector2Array([p.call(-w * 0.5, 40 - h), p.call(0, 22 - h), p.call(w * 0.5, 40 - h)]), W)
		"it":
			c.draw_rect(Rect2(p.call(-30, -26), Vector2(60, 40) * s), W)
			c.draw_rect(Rect2(p.call(-24, -20), Vector2(48, 28) * s), Color(0, 0, 0, 0.35))
			c.draw_colored_polygon(PackedVector2Array([p.call(-40, 22), p.call(40, 22), p.call(34, 30), p.call(-34, 30)]), W)
			line.call(p.call(-12, -10), p.call(-4, -4), 3)
			line.call(p.call(-12, 2), p.call(-4, -4), 3)
		"bank":
			c.draw_colored_polygon(PackedVector2Array([p.call(-40, -14), p.call(0, -38), p.call(40, -14)]), W)
			for i in 4:
				c.draw_rect(Rect2(p.call(-32 + i * 19, -8), Vector2(8, 36) * s), W)
			c.draw_rect(Rect2(p.call(-42, 28), Vector2(84, 8) * s), W)
		"oil":
			line.call(p.call(-24, 36), p.call(0, -36), 6)
			line.call(p.call(24, 36), p.call(0, -36), 6)
			line.call(p.call(-14, 6), p.call(14, 6), 5)
			line.call(p.call(-19, 20), p.call(19, 20), 5)
			c.draw_circle(p.call(30, -14), 9 * s, W)
			c.draw_colored_polygon(PackedVector2Array([p.call(22, -18), p.call(30, -34), p.call(38, -18)]), W)
		"room":
			c.draw_rect(Rect2(p.call(-38, 0), Vector2(76, 18) * s), W)
			c.draw_rect(Rect2(p.call(-38, -20), Vector2(10, 46) * s), W)
			c.draw_rect(Rect2(p.call(-24, -12), Vector2(26, 12) * s), W)
		"house", "mansion":
			var w := 70.0 if id == "mansion" else 52.0
			c.draw_rect(Rect2(p.call(-w * 0.5, -6), Vector2(w, 40) * s), W)
			c.draw_colored_polygon(PackedVector2Array([p.call(-w * 0.5 - 8, -4), p.call(0, -36), p.call(w * 0.5 + 8, -4)]), W)
			c.draw_rect(Rect2(p.call(-7, 12), Vector2(14, 22) * s), Color(0, 0, 0, 0.35))
			if id == "mansion":
				for sx in [-1.0, 1.0]:
					c.draw_rect(Rect2(p.call(sx * 24 - 3, 0), Vector2(6, 34) * s), Color(0, 0, 0, 0.2))
		"bike":
			c.draw_arc(p.call(-24, 14), 16 * s, 0, TAU, 24, W, 5 * s, true)
			c.draw_arc(p.call(24, 14), 16 * s, 0, TAU, 24, W, 5 * s, true)
			line.call(p.call(-24, 14), p.call(-4, -12), 5)
			line.call(p.call(-4, -12), p.call(18, -12), 5)
			line.call(p.call(18, -12), p.call(24, 14), 5)
			line.call(p.call(-4, -12), p.call(2, 14), 5)
			line.call(p.call(2, 14), p.call(24, 14), 5)
		"oldcar":
			_car(c, p, 0.0)
		"car":
			_car(c, p, 0.5)
		"sportcar":
			_car(c, p, 1.0)
		"yacht":
			c.draw_colored_polygon(PackedVector2Array([p.call(-44, 8), p.call(44, 8), p.call(30, 28), p.call(-34, 28)]), W)
			c.draw_colored_polygon(PackedVector2Array([p.call(-20, 8), p.call(-12, -10), p.call(24, -10), p.call(30, 8)]), W)
			line.call(p.call(0, -10), p.call(0, -38), 4)
		"jet":
			c.draw_colored_polygon(PackedVector2Array([p.call(-44, 4), p.call(36, -6), p.call(46, 0), p.call(36, 6), p.call(-44, 8)]), W)
			c.draw_colored_polygon(PackedVector2Array([p.call(-6, 2), p.call(-22, 30), p.call(-12, 30), p.call(12, 4)]), W)
			c.draw_colored_polygon(PackedVector2Array([p.call(-6, 0), p.call(-22, -26), p.call(-12, -26), p.call(12, -2)]), W)
			c.draw_colored_polygon(PackedVector2Array([p.call(-44, 4), p.call(-48, -16), p.call(-38, -16), p.call(-32, 2)]), W)
		"coin":
			c.draw_circle(m, 40 * s, W)
			c.draw_arc(m, 30 * s, 0, TAU, 32, Color(0, 0, 0, 0.18), 5 * s, true)
			var f := ThemeDB.fallback_font
			var t := "$"
			var size := int(48 * s)
			var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
			c.draw_string(f, m + Vector2(-ts.x * 0.5, size * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.45))


## A side view of a car; `sport` 0 = boxy old car, 1 = low sports car.
static func _car(c: CanvasItem, p: Callable, sport: float) -> void:
	var roof := lerpf(-24, -12, sport)
	var body := PackedVector2Array([p.call(-44, 14), p.call(-44, 0), p.call(-26, -2), p.call(lerpf(-16, -6, sport), roof),
		p.call(lerpf(16, 18, sport), roof), p.call(lerpf(28, 34, sport), -2), p.call(44, 2), p.call(44, 14)])
	c.draw_colored_polygon(body, W)
	var s: float = (p.call(1, 0) - p.call(0, 0)).x
	c.draw_circle(p.call(-24, 16), 11 * s, W)
	c.draw_circle(p.call(24, 16), 11 * s, W)
	c.draw_circle(p.call(-24, 16), 5 * s, Color(0, 0, 0, 0.35))
	c.draw_circle(p.call(24, 16), 5 * s, Color(0, 0, 0, 0.35))
