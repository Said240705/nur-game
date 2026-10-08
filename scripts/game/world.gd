extends Control
## The mine in cross-section, drawn from code: a dusk sky over the hills, the
## lift's headframe and the shop on the surface, then one tunnel per shaft,
## deeper and richer in colour, each with its miner, crate and vein of ore.
## Swipe to scroll; tap a worker to wake him, tap a level badge to upgrade.

signal open_station(id: String)
signal buy_shaft
## A tap that hit nothing, e.g. to close the upgrade panel.
signal tapped_nothing

const Eco := preload("res://scripts/game/economy.gd")
const UI := preload("res://scripts/ui/ui.gd")

const W := 1080.0
const TOP := 260.0
const SURF := 470.0
const SH := 320.0
const TUNNEL_TOP := 84.0
const TUNNEL_BOTTOM := 284.0
const COLUMN := Vector2(70, 230)
const CRATE_X := 262.0
const MINER_FROM := 400.0
const MINER_TO := 905.0
const PILE_X := 330.0
const SHOP_DOOR := 790.0

var mine: RefCounted
var scroll := 0.0
## Space covered by the panel at the bottom; the mine can scroll above it.
var bottom_inset := 0.0

var _t := 0.0
var _vel := 0.0
var _pressing := false
var _moved := 0.0
var _press_at := Vector2.ZERO
var _last_y := 0.0
var _floaters: Array = []
var _sparks: Array = []
var _glow: Control
var _font: Font
var _rocks := {}
## Tap targets in content coordinates: [Rect2, kind, id].
var _hits: Array = []


func _ready() -> void:
	_font = UI.font(800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glow = Control.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func ground() -> float:
	return TOP + SURF - 70.0


func shaft_top(k: int) -> float:
	return TOP + SURF + k * SH


func content_height() -> float:
	return shaft_top(mine.shafts.size() + 1) + 140.0


func max_scroll() -> float:
	return maxf(0.0, content_height() - size.y + bottom_inset)


## Screen position of a point in the mine.
func to_screen(p: Vector2) -> Vector2:
	return p - Vector2(0, scroll)


# --- Input ------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_moved = 0.0
			_vel = 0.0
			_press_at = event.position
			_last_y = event.position.y
		elif _pressing:
			_pressing = false
			if _moved < 24.0:
				_tap(event.position + Vector2(0, scroll))
	elif event is InputEventMouseMotion and _pressing:
		var dy: float = event.position.y - _last_y
		_last_y = event.position.y
		_moved += absf(dy)
		if _moved >= 24.0:
			scroll = clampf(scroll - dy, 0.0, max_scroll())
			_vel = lerpf(_vel, -dy / maxf(get_process_delta_time(), 0.001), 0.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = clampf(scroll - 120.0, 0.0, max_scroll())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = clampf(scroll + 120.0, 0.0, max_scroll())


func _tap(p: Vector2) -> void:
	# Badges first: they sit on top of the workers' areas.
	for pass_kind in ["badge", "buy", "worker"]:
		for h in _hits:
			if h[1] == pass_kind and (h[0] as Rect2).has_point(p):
				match pass_kind:
					"badge":
						open_station.emit(h[2])
					"buy":
						buy_shaft.emit()
					"worker":
						if mine.tap(h[2]):
							Sfx.play("click", -8.0)
				return
	tapped_nothing.emit()


## Scroll so the newest shaft is in view.
func reveal_bottom() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scroll", max_scroll(), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Effects ----------------------------------------------------------------------

func float_text(text: String, at: Vector2, color: Color, size_px := 44) -> void:
	_floaters.append({"text": text, "p": at, "t": 0.0, "c": color, "s": size_px})


func coin_burst(at: Vector2, n := 10) -> void:
	for i in n:
		_sparks.append({"p": at, "v": Vector2(randf_range(-260, 260), randf_range(-700, -300)), "t": 0.0,
			"life": randf_range(0.6, 1.0), "c": Color("#ffd447")})


func _process(delta: float) -> void:
	_t += delta
	if not _pressing and absf(_vel) > 5.0:
		scroll = clampf(scroll + _vel * delta, 0.0, max_scroll())
		_vel *= pow(0.05, delta)
	scroll = clampf(scroll, 0.0, max_scroll())
	for f in _floaters:
		f["t"] += delta
		f["p"] += Vector2(0, -90) * delta
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return f["t"] < 1.3)
	for s in _sparks:
		s["t"] += delta
		s["v"] += Vector2(0, 1500) * delta
		s["p"] += s["v"] * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["t"] < s["life"])
	queue_redraw()
	_glow.queue_redraw()


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	_hits.clear()
	draw_set_transform(Vector2(0, -scroll))
	_draw_sky()
	_draw_surface()
	for k in mine.shafts.size():
		_draw_shaft(k)
	_draw_locked(mine.shafts.size())
	_draw_column()
	_draw_cage()
	for s in _sparks:
		var k: float = s["t"] / s["life"]
		draw_circle(s["p"], 11.0 * (1.0 - k * 0.4), Color(s["c"], 1.0 - k))
		draw_circle(s["p"] - Vector2(3, 3), 4.0, Color(1, 1, 1, (1.0 - k) * 0.8))
	for f in _floaters:
		var k: float = f["t"] / 1.3
		var col: Color = f["c"]
		col.a = 1.0 - k * k
		_text(f["text"], f["p"], f["s"], col, true)


func _draw_sky() -> void:
	var g := ground()
	var top := Color("#1d2457")
	var mid := Color("#7a4d8f")
	var low := Color("#ff9e6b")
	_vgrad(Rect2(0, -2000, W, 2000 + TOP), top, top)
	_vgrad(Rect2(0, TOP, W, (g - TOP) * 0.55), top, mid)
	_vgrad(Rect2(0, TOP + (g - TOP) * 0.55, W, (g - TOP) * 0.45 + 10), mid, low)
	# The sun sinking behind the hills.
	draw_circle(Vector2(560, g - 120), 70, Color("#ffd27a"))
	# Two ranges of hills, the far one paler.
	_hills(g - 70, Color("#6b4c86"), 0.0, 60.0)
	_hills(g - 20, Color("#3e2f5e"), 2.0, 45.0)


func _hills(base: float, col: Color, seed_phase: float, amp: float) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, base + 200))
	for i in 25:
		var x := i * W / 24.0
		pts.append(Vector2(x, base - amp * (0.5 + 0.5 * sin(x / 140.0 + seed_phase)) - amp * 0.4 * sin(x / 61.0 + seed_phase * 2.0)))
	pts.append(Vector2(W, base + 200))
	draw_colored_polygon(pts, col)


func _draw_surface() -> void:
	var g := ground()
	# Earth under the grass down to the first tunnel.
	_vgrad(Rect2(0, g, W, TOP + SURF - g), Color("#7a5236"), Color("#6b4a2f"))
	draw_rect(Rect2(0, g - 6, W, 22), Color("#4caf50"))
	draw_rect(Rect2(0, g + 12, W, 6), Color("#2e7d32"))
	# The shop: a little warehouse with a lit window and a sign.
	var shop := Rect2(760, g - 230, 280, 230)
	draw_rect(shop, Color("#c9744a"))
	draw_rect(Rect2(shop.position + Vector2(0, shop.size.y - 18), Vector2(shop.size.x, 18)), Color("#8d4f30"))
	for i in 6:
		draw_line(shop.position + Vector2(0, 40 + i * 32), shop.position + Vector2(shop.size.x, 40 + i * 32), Color(0, 0, 0, 0.08), 3)
	draw_colored_polygon(PackedVector2Array([shop.position + Vector2(-24, 0), shop.position + Vector2(shop.size.x * 0.5, -86),
		shop.position + Vector2(shop.size.x + 24, 0)]), Color("#5b3a8a"))
	draw_rect(Rect2(shop.position + Vector2(24, 120), Vector2(90, 110)), Color("#3a2416"))
	draw_rect(Rect2(shop.position + Vector2(160, 70), Vector2(90, 70)), Color("#ffd27a"))
	draw_rect(Rect2(shop.position + Vector2(160, 70), Vector2(90, 70)), Color("#5b3a1e"), false, 6)
	var sign := Rect2(shop.position + Vector2(70, -50), Vector2(140, 46))
	draw_rect(sign, Color("#3a2416"))
	_text("СКЛАД", sign.get_center() + Vector2(0, 2), 30, Color("#ffd447"))
	_hits.append([shop, "worker", "cart"])
	_badge(Rect2(500, g - 260, 230, 66), "cart")
	# The ore pile waiting by the lift.
	if mine.pile > 0.0:
		var h := clampf(log(mine.pile + 1.0) * 6.0, 14.0, 80.0)
		draw_colored_polygon(_mound(Vector2(PILE_X, g + 4), 90.0, h), Color("#55606e"))
		_text(Eco.short(mine.pile), Vector2(PILE_X, g - h - 30), 36, Color.WHITE, true)
	_draw_carter()
	# The headframe over the lift: two legs, a cross brace and the big wheel.
	var top := g - 300
	var x0 := COLUMN.x - 10
	var x1 := COLUMN.y + 10
	draw_line(Vector2(x0, g), Vector2(x0 + 50, top), Color("#4b3a52"), 14)
	draw_line(Vector2(x1, g), Vector2(x1 - 50, top), Color("#4b3a52"), 14)
	for i in 3:
		var y := g - 80 - i * 75
		draw_line(Vector2(x0 + 14 + i * 12, y), Vector2(x1 - 14 - i * 12, y), Color("#4b3a52"), 8)
	var hub := Vector2((COLUMN.x + COLUMN.y) * 0.5, top - 10)
	draw_circle(hub, 52, Color("#2f2538"))
	draw_arc(hub, 52, 0, TAU, 40, Color("#8a7a96"), 8, true)
	var spin: float = mine.lift["y"] * 4.0
	for i in 6:
		draw_line(hub, hub + Vector2.from_angle(spin + i * TAU / 6.0) * 48, Color("#8a7a96"), 5)
	draw_circle(hub, 10, Color("#ffd447"))
	_badge(Rect2(COLUMN.y + 40, top - 40, 230, 66), "lift")


func _draw_carter() -> void:
	var g := ground()
	var walk := Eco.cart_walk(mine.cart["level"])
	var phase: String = mine.cart["phase"]
	var k := 0.0
	var x := SHOP_DOOR
	var facing := -1.0
	match phase:
		"go":
			k = mine.cart["t"] / walk
			x = lerpf(SHOP_DOOR, PILE_X + 110, k)
		"return":
			k = mine.cart["t"] / walk
			x = lerpf(PILE_X + 110, SHOP_DOOR, k)
			facing = 1.0
	var moving := phase != "idle"
	# A wheelbarrow pushed ahead of the worker.
	var barrow := Vector2(x + facing * 70, g - 30)
	draw_colored_polygon(PackedVector2Array([barrow + Vector2(-40, -26), barrow + Vector2(40, -26), barrow + Vector2(28, 8), barrow + Vector2(-28, 8)]), Color("#7d8a99"))
	if mine.cart["carry"] > 0.0:
		draw_colored_polygon(_mound(barrow + Vector2(0, -24), 36, 22), Color("#55606e"))
	draw_circle(barrow + Vector2(facing * 26, 18), 13, Color("#2b2b33"))
	_person(Vector2(x, g), facing, moving, false, mine.cart["carry"] > 0.0, Color("#3d8bff"), false)
	if phase == "idle" and not mine.cart["manager"] and mine.pile > 0.0:
		_tap_ring(Vector2(x, g - 70))


func _draw_shaft(k: int) -> void:
	var y0 := shaft_top(k)
	var ore: Dictionary = Eco.ORES[k]
	var depth := k / 9.0
	var rock := Color("#6b4a2f").lerp(Color("#2c1f45"), depth)
	_vgrad(Rect2(0, y0, W, SH), rock, rock.darkened(0.18))
	_pebbles(k, Rect2(0, y0, W, SH), rock)
	var tunnel := Rect2(COLUMN.y, y0 + TUNNEL_TOP, W - COLUMN.y, TUNNEL_BOTTOM - TUNNEL_TOP)
	draw_rect(tunnel, rock.darkened(0.55))
	_vgrad(Rect2(tunnel.position, Vector2(tunnel.size.x, 40)), Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	var floor_y := y0 + TUNNEL_BOTTOM
	draw_rect(Rect2(COLUMN.y, floor_y - 14, W - COLUMN.y, 14), Color("#6d4c33"))
	for i in 3:
		var px := 440.0 + i * 220.0
		draw_rect(Rect2(px - 9, y0 + TUNNEL_TOP, 18, TUNNEL_BOTTOM - TUNNEL_TOP), Color("#8a5a36"))
		draw_rect(Rect2(px - 60, y0 + TUNNEL_TOP, 120, 16), Color("#8a5a36"))
		draw_circle(Vector2(px, y0 + TUNNEL_TOP + 34), 9, Color("#ffe8a3"))
	# The vein at the end of the tunnel.
	_vein(k, Rect2(MINER_TO + 40, y0 + TUNNEL_TOP, W - MINER_TO - 40, TUNNEL_BOTTOM - TUNNEL_TOP), rock, ore["color"])
	# Crate by the lift with the ore dug so far.
	var s: Dictionary = mine.shafts[k]
	var crate := Rect2(CRATE_X, floor_y - 74, 104, 60)
	if s["stock"] > 0.0:
		draw_colored_polygon(_mound(Vector2(crate.get_center().x, crate.position.y + 6), 48, clampf(log(s["stock"] + 1.0) * 3.0, 8.0, 34.0)), ore["color"].darkened(0.1))
		_text(Eco.short(s["stock"]), Vector2(crate.get_center().x, crate.position.y - 50), 34, Color.WHITE, true)
	draw_rect(crate, Color("#a0683e"))
	draw_rect(crate, Color("#6d4428"), false, 6)
	draw_line(crate.position + Vector2(0, 30), crate.end - Vector2(0, 30), Color("#6d4428"), 5)
	_draw_miner(k, floor_y, ore["color"])
	_hits.append([tunnel, "worker", "shaft:%d" % k])
	# Name of the shaft and its level badge on the rock above the tunnel.
	_text("%d · %s" % [k + 1, ore["name"]], Vector2(COLUMN.y + 24, y0 + 44), 34, Color(1, 1, 1, 0.85), true, HORIZONTAL_ALIGNMENT_LEFT)
	_badge(Rect2(W - 260, y0 + 10, 230, 66), "shaft:%d" % k)


func _draw_miner(k: int, floor_y: float, ore_color: Color) -> void:
	var s: Dictionary = mine.shafts[k]
	var phase: String = s["phase"]
	var t: float = s["t"]
	var x := MINER_FROM
	var facing := 1.0
	match phase:
		"walk":
			x = lerpf(MINER_FROM, MINER_TO, t / Eco.WALK)
		"dig":
			x = MINER_TO
		"back":
			x = lerpf(MINER_TO, MINER_FROM, t / Eco.WALK)
			facing = -1.0
	_person(Vector2(x, floor_y - 14), facing, phase == "walk" or phase == "back", phase == "dig", phase == "back", Color("#ff9a3c"), true, ore_color)
	if phase == "idle" and not s["manager"]:
		_tap_ring(Vector2(x, floor_y - 90))


## A little worker: legs, body, round head and a yellow helmet with a lamp.
## `digger` swings a pickaxe; `carrying` shows a sack of ore on the back.
func _person(feet: Vector2, facing: float, walking: bool, digging: bool, carrying: bool, shirt: Color, digger: bool, ore := Color.GRAY) -> void:
	var step := sin(_t * 14.0) if walking else 0.0
	var bob := absf(step) * 4.0 if walking else 0.0
	var hip := feet + Vector2(0, -34 - bob)
	draw_line(hip + Vector2(-8, 0), feet + Vector2(-8 + step * 10, 0), Color("#2b2d42"), 11)
	draw_line(hip + Vector2(8, 0), feet + Vector2(8 - step * 10, 0), Color("#2b2d42"), 11)
	if carrying:
		draw_circle(hip + Vector2(-facing * 26, -36), 22, Color("#8d6e4c"))
		draw_circle(hip + Vector2(-facing * 30, -44), 6, ore)
	draw_rect(Rect2(hip + Vector2(-20, -54), Vector2(40, 58)), shirt)
	draw_rect(Rect2(hip + Vector2(-20, -10), Vector2(40, 8)), Color("#5b3a1e"))
	var head := hip + Vector2(0, -74)
	draw_circle(head, 21, Color("#f2c19b"))
	draw_circle(head + Vector2(facing * 8, -2), 3.2, Color("#2b2d42"))
	# Helmet with a brim and a lamp facing forward.
	draw_arc(head + Vector2(0, -4), 23, PI, TAU, 16, Color("#ffd447"), 14, true)
	draw_line(head + Vector2(-27, -2), head + Vector2(27, -2), Color("#e6b800"), 6)
	draw_circle(head + Vector2(facing * 16, -14), 6, Color("#fff6c8"))
	var shoulder := hip + Vector2(facing * 8, -44)
	if digger:
		var swing := (0.9 + 1.1 * (0.5 + 0.5 * sin(_t * 12.0))) if digging else 0.6
		var dir := Vector2.from_angle(-PI * 0.5 + facing * swing)
		var tip := shoulder + dir * 56
		draw_line(shoulder, tip, Color("#8a5a36"), 7)
		var head_dir := dir.orthogonal() * facing
		draw_line(tip - head_dir * 22, tip + head_dir * 22, Color("#c0c7d1"), 8)
	else:
		draw_line(shoulder, shoulder + Vector2(facing * 26, 14), shirt.darkened(0.2), 9)


func _tap_ring(at: Vector2) -> void:
	var k := fmod(_t * 1.2, 1.0)
	draw_arc(at, 26 + k * 34, 0, TAU, 32, Color(1, 1, 1, 0.8 * (1.0 - k)), 5, true)
	draw_circle(at, 12, Color(1, 1, 1, 0.9))


func _vein(k: int, r: Rect2, rock: Color, ore: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + k
	var pts := PackedVector2Array()
	pts.append(r.position + Vector2(r.size.x, 0))
	for i in 9:
		pts.append(Vector2(r.position.x + rng.randf_range(0, 26), r.position.y + i * r.size.y / 8.0))
	pts.append(r.end)
	draw_colored_polygon(pts, rock.darkened(0.15))
	for i in 7:
		var c := Vector2(rng.randf_range(r.position.x + 30, r.end.x - 14), rng.randf_range(r.position.y + 18, r.end.y - 18))
		var s := rng.randf_range(10, 20)
		var gem := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)])
		draw_colored_polygon(gem, ore)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c]), ore.lightened(0.4))


func _draw_locked(k: int) -> void:
	var y0 := shaft_top(k)
	var rock := Color("#2a1f3a")
	_vgrad(Rect2(0, y0, W, SH + 200), rock, Color("#120d1c"))
	# Solid bedrock below, however tall the screen.
	draw_rect(Rect2(0, y0 + SH + 200, W, 4000), Color("#120d1c"))
	_pebbles(k, Rect2(0, y0, W, SH), rock)
	var price: float = mine.next_shaft_cost()
	if price < 0.0:
		_text("Самое дно. Глубже некуда!", Vector2(W * 0.5, y0 + SH * 0.5), 44, Color(1, 1, 1, 0.6), true)
		return
	var ore: Dictionary = Eco.ORES[k]
	var r := Rect2(W * 0.5 - 330, y0 + SH * 0.5 - 70, 660, 140)
	var can: bool = mine.coins >= price
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffd447") if can else Color(1, 1, 1, 0.1)
	sb.set_corner_radius_all(70)
	sb.shadow_color = Color(1, 0.8, 0.3, 0.5) if can else Color(0, 0, 0, 0)
	sb.shadow_size = 24
	draw_style_box(sb, r)
	var ink := Color("#2a1a08") if can else Color(1, 1, 1, 0.8)
	_text("Новая шахта: " + ore["name"], r.get_center() + Vector2(0, -22), 40, ink)
	_text(Eco.short(price) + " монет", r.get_center() + Vector2(0, 26), 36, ink)
	_hits.append([r, "buy", ""])


func _draw_column() -> void:
	var g := ground()
	var bottom := shaft_top(mine.shafts.size())
	draw_rect(Rect2(COLUMN.x, g, COLUMN.y - COLUMN.x, bottom - g), Color("#1b1424"))
	draw_line(Vector2(COLUMN.x + 6, g), Vector2(COLUMN.x + 6, bottom), Color("#4b3a52"), 8)
	draw_line(Vector2(COLUMN.y - 6, g), Vector2(COLUMN.y - 6, bottom), Color("#4b3a52"), 8)
	for k in mine.shafts.size():
		draw_rect(Rect2(COLUMN.x, shaft_top(k) + TUNNEL_BOTTOM - 10, COLUMN.y - COLUMN.x, 10), Color("#4b3a52"))


func cage_y(level_y: float) -> float:
	# Piecewise: the surface stop, then one stop per shaft floor.
	var stop := func(i: int) -> float:
		return ground() - 150.0 if i < 0 else shaft_top(i) + TUNNEL_BOTTOM - 160.0
	var lo := floori(level_y)
	var f := level_y - lo
	return lerpf(stop.call(lo), stop.call(lo + 1), f)


func _draw_cage() -> void:
	var y := cage_y(mine.lift["y"])
	var hub := Vector2((COLUMN.x + COLUMN.y) * 0.5, ground() - 310)
	draw_line(hub, Vector2(hub.x, y), Color("#c0c7d1"), 4)
	var cage := Rect2(COLUMN.x + 14, y, COLUMN.y - COLUMN.x - 28, 150)
	draw_rect(cage, Color("#2f3d55"))
	if mine.lift["load"] > 0.0:
		draw_colored_polygon(_mound(Vector2(cage.get_center().x, cage.end.y - 12), 54, 40), Color("#7d8a99"))
	for i in 4:
		var x := cage.position.x + 10 + i * (cage.size.x - 20) / 3.0
		draw_line(Vector2(x, cage.position.y), Vector2(x, cage.end.y), Color("#9fb0c8"), 4)
	draw_rect(cage, Color("#9fb0c8"), false, 6)
	draw_rect(Rect2(cage.position.x - 6, cage.position.y - 12, cage.size.x + 12, 14), Color("#ffd447"))
	if mine.lift["load"] > 0.0:
		_text(Eco.short(mine.lift["load"]), Vector2(cage.get_center().x, cage.position.y - 40), 32, Color.WHITE, true)
	_hits.append([Rect2(COLUMN.x, ground() - 200, COLUMN.y - COLUMN.x, content_height()), "worker", "lift"])
	if mine.lift["phase"] == "idle" and not mine.lift["manager"]:
		_tap_ring(cage.get_center())


## A rounded badge with the level; glows gold when an upgrade is affordable.
func _badge(r: Rect2, id: String) -> void:
	var can: bool = mine.coins >= mine.cost(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#ffd447") if can else Color(0.08, 0.06, 0.14, 0.85)
	sb.set_corner_radius_all(33)
	sb.border_color = Color("#ffd447")
	sb.set_border_width_all(0 if can else 3)
	sb.shadow_color = Color(1, 0.8, 0.3, 0.45 + 0.25 * sin(_t * 5.0)) if can else Color(0, 0, 0, 0.3)
	sb.shadow_size = 18
	draw_style_box(sb, r)
	var ink := Color("#2a1a08") if can else Color("#ffd447")
	_text("Ур. %d" % mine.level(id), r.get_center() + Vector2(-20, 0), 34, ink)
	# An up arrow.
	var a := r.get_center() + Vector2(72, 0)
	draw_colored_polygon(PackedVector2Array([a + Vector2(0, -16), a + Vector2(14, 2), a + Vector2(-14, 2)]), ink)
	draw_rect(Rect2(a + Vector2(-5, 2), Vector2(10, 12)), ink)
	if mine.has_manager(id):
		var m := r.position + Vector2(-22, r.size.y * 0.5)
		draw_circle(m, 22, Color("#2ee59d"))
		_text("A", m, 26, Color("#0b3b2a"))
	_hits.append([r.grow(10), "badge", id])


# --- Glow layer ---------------------------------------------------------------------

func _draw_glow() -> void:
	_glow.draw_set_transform(Vector2(0, -scroll))
	var g := ground()
	_soft(Vector2(560, g - 120), 320, Color(1, 0.6, 0.3, 0.35))
	_soft(Rect2(760, g - 230, 280, 230).position + Vector2(205, 105), 110, Color(1, 0.8, 0.4, 0.4))
	for k in mine.shafts.size():
		var y0 := shaft_top(k)
		for i in 3:
			_soft(Vector2(440.0 + i * 220.0, y0 + TUNNEL_TOP + 40), 120, Color(1, 0.75, 0.4, 0.22))
		var ore: Color = Eco.ORES[k]["color"]
		var tw := 0.5 + 0.5 * sin(_t * 2.0 + k)
		_soft(Vector2(1000, y0 + (TUNNEL_TOP + TUNNEL_BOTTOM) * 0.5), 130, Color(ore, 0.18 + 0.12 * tw))
		# The miner's headlamp lights the rock ahead.
		var s: Dictionary = mine.shafts[k]
		var x := MINER_FROM
		var facing := 1.0
		match s["phase"]:
			"walk":
				x = lerpf(MINER_FROM, MINER_TO, s["t"] / Eco.WALK)
			"dig":
				x = MINER_TO
			"back":
				x = lerpf(MINER_TO, MINER_FROM, s["t"] / Eco.WALK)
				facing = -1.0
		# Feet, hips, head, then the lamp on the helmet (see _person).
		var lamp := Vector2(x + facing * 16, y0 + TUNNEL_BOTTOM - 14 - 34 - 74 - 14)
		_glow.draw_colored_polygon(PackedVector2Array([lamp, lamp + Vector2(facing * 240, -60), lamp + Vector2(facing * 240, 70)]),
			Color(1, 0.95, 0.7, 0.12))
		_soft(lamp, 40, Color(1, 0.95, 0.7, 0.5))
	for s in _sparks:
		_soft(s["p"], 34, Color(1, 0.8, 0.3, 0.5 * (1.0 - s["t"] / s["life"])))


func _soft(at: Vector2, r: float, col: Color) -> void:
	var steps := 6
	for i in steps:
		var k := 1.0 - float(i) / steps
		_glow.draw_circle(at, r * k, Color(col, col.a / steps * 1.6))


# --- Small drawing helpers ----------------------------------------------------------

func _vgrad(r: Rect2, a: Color, b: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([a, a, b, b]))


func _mound(base: Vector2, half_w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(base + Vector2(-cos(a) * half_w, -sin(a) * h))
	return pts


func _pebbles(k: int, r: Rect2, rock: Color) -> void:
	if not _rocks.has(k):
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + k
		var list := []
		for i in 26:
			list.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(5, 16)))
		_rocks[k] = list
	for p in _rocks[k]:
		var at := r.position + Vector2(p.x * r.size.x, p.y * r.size.y)
		draw_circle(at, p.z, rock.darkened(0.25))
		draw_circle(at - Vector2(p.z * 0.3, p.z * 0.3), p.z * 0.35, rock.lightened(0.12))


func _text(text: String, center: Vector2, size_px: int, col: Color, shadow := false, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var x := center.x - w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else center.x
	var y := center.y + size_px * 0.36
	if shadow:
		draw_string(_font, Vector2(x + 2, y + 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, col.a * 0.6))
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
