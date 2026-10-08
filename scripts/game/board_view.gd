extends Control
## Draws the board: a glass panel with empty slots, glowing gem blocks, the
## ghost of the piece being dragged (the lines it would finish shimmer under a
## glowing band, so it is clear they are about to burst), a pop when blocks
## land, the burst of cleared lines and the slow turn to stone when the round
## is over.

const Board := preload("res://scripts/game/board.gd")
const Blocks := preload("res://scripts/game/blocks.gd")
const PAD := 16.0
const GAP := 7.0
const POP_TIME := 0.32
const CLEAR_TIME := 0.42

var board: Board
var cell := 112.0

var _pop := {}
var _clearing: Array = []
var _ghost := {}
var _lit := {}
var _lines := {"rows": [], "cols": []}
var _stone := -1.0
var _t := 0.0
var _panel: StyleBoxFlat
var _slot: StyleBoxFlat
var _glow_layer: Control


func setup(b: Board, width: float) -> void:
	board = b
	cell = (width - PAD * 2.0 - GAP * (Board.N - 1)) / Board.N
	size = Vector2(width, width)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.06, 0.05, 0.16, 0.72)
	_panel.set_corner_radius_all(40)
	_panel.border_color = Color(1, 1, 1, 0.09)
	_panel.set_border_width_all(2)
	_panel.shadow_color = Color(0.02, 0.0, 0.08, 0.55)
	_panel.shadow_size = 40
	_panel.shadow_offset = Vector2(0, 18)
	_panel.anti_aliasing = true
	_slot = StyleBoxFlat.new()
	_slot.bg_color = Color(1, 1, 1, 0.045)
	_slot.set_corner_radius_all(18)
	_slot.anti_aliasing = true
	# Halos are added on top of the blocks: a soft neon bloom.
	_glow_layer = Control.new()
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = add
	_glow_layer.draw.connect(_draw_glow)
	add_child(_glow_layer)


func pitch() -> float:
	return cell + GAP


func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(PAD + c.x * pitch(), PAD + c.y * pitch())


func cell_center(c: Vector2i) -> Vector2:
	return cell_pos(c) + Vector2(cell, cell) * 0.5


## The board square nearest to a piece whose top-left corner is at `local`.
func grid_at(local: Vector2) -> Vector2i:
	var g := (local - Vector2(PAD, PAD)) / pitch()
	return Vector2i(roundi(g.x), roundi(g.y))


func show_ghost(shape: Array[Vector2i], pos: Vector2i, color: int, lines: Dictionary) -> void:
	_ghost = {"shape": shape, "pos": pos, "color": color}
	_lines = lines
	_lit = {}
	for r in lines["rows"]:
		for x in Board.N:
			_lit[Vector2i(x, r)] = true
	for c in lines["cols"]:
		for y in Board.N:
			_lit[Vector2i(c, y)] = true


func hide_ghost() -> void:
	_ghost = {}
	_lit = {}
	_lines = {"rows": [], "cols": []}


func popped(cells: Array) -> void:
	for c in cells:
		_pop[c] = 0.0


## Cleared squares burst one after another, rippling out from `origin`.
func cleared(gone: Array, origin: Vector2) -> void:
	for g in gone:
		var c: Vector2i = g[0]
		var delay := (Vector2(c) - origin).length() * 0.03
		_clearing.append({"cell": c, "color": g[1], "t": -delay})


func turn_to_stone() -> void:
	_stone = 0.0


func reset() -> void:
	_pop.clear()
	_clearing.clear()
	_stone = -1.0
	hide_ghost()


func _process(delta: float) -> void:
	_t += delta
	for c in _pop.keys():
		_pop[c] += delta
		if _pop[c] > POP_TIME:
			_pop.erase(c)
	for e in _clearing:
		e["t"] += delta
	_clearing = _clearing.filter(func(e: Dictionary) -> bool: return e["t"] < CLEAR_TIME)
	if _stone >= 0.0:
		_stone += delta * 14.0
	queue_redraw()
	_glow_layer.queue_redraw()


func _draw() -> void:
	draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	for y in Board.N:
		for x in Board.N:
			draw_style_box(_slot, Rect2(cell_pos(Vector2i(x, y)), Vector2(cell, cell)))
	# Lines about to burst: a glowing band under them. Colours do not matter,
	# only that the line is full.
	var pulse := 0.5 + 0.5 * sin(_t * 8.0)
	var band := Color(1, 1, 1, 0.13 + 0.12 * pulse)
	var span := Board.N * pitch() - GAP
	for r in _lines["rows"]:
		draw_rect(Rect2(Vector2(PAD - 6, cell_pos(Vector2i(0, r)).y - 6), Vector2(span + 12, cell + 12)), band)
	for c in _lines["cols"]:
		draw_rect(Rect2(Vector2(cell_pos(Vector2i(c, 0)).x - 6, PAD - 6), Vector2(cell + 12, span + 12)), band)
	for y in Board.N:
		for x in Board.N:
			var c := Vector2i(x, y)
			var v := board.at(c)
			if v == 0:
				continue
			var tint := Color.WHITE
			var s := 1.0
			if _lit.has(c):
				# Each block in a line about to burst shivers and brightens.
				var b := 1.1 + 0.2 * pulse
				tint = Color(b, b, b)
				s = 1.0 + 0.05 * sin(_t * 22.0 + x + y)
			if _stone >= 0.0 and y < _stone:
				v = Blocks.STONE
			if _pop.has(c):
				var k: float = _pop[c] / POP_TIME
				s = 1.0 + 0.16 * sin(k * PI) * (1.0 - k * 0.5)
			_block(c, v, s, tint)
	if not _ghost.is_empty():
		for o in _ghost["shape"]:
			var lit: bool = _lit.has(_ghost["pos"] + o)
			_block(_ghost["pos"] + o, _ghost["color"], 1.0, Color(1, 1, 1, 0.75 if lit else 0.45))
	for e in _clearing:
		var t: float = e["t"]
		if t < 0.0:
			_block(e["cell"], e["color"], 1.0, Color.WHITE)
			continue
		var k := t / CLEAR_TIME
		_block(e["cell"], e["color"], 1.0 + 0.25 * k - 1.25 * k * k, Color(1, 1, 1, 1.0 - k * k))
		# A white flash at the start of the burst.
		var flash := 1.0 - k * 3.0
		if flash > 0.0:
			var r := Rect2(cell_pos(e["cell"]), Vector2(cell, cell))
			draw_rect(r.grow(-cell * 0.08), Color(1, 1, 1, flash * 0.8))


func _block(c: Vector2i, color: int, s: float, tint: Color) -> void:
	if s <= 0.0:
		return
	var center := cell_center(c)
	var half := Vector2(cell, cell) * 0.5 * s
	draw_texture_rect(Blocks.block(color), Rect2(center - half, half * 2.0), false, tint)


func _draw_glow() -> void:
	var tex := Blocks.glow()
	for y in Board.N:
		for x in Board.N:
			var c := Vector2i(x, y)
			var v := board.at(c)
			if v == 0 or (_stone >= 0.0 and y < _stone):
				continue
			_halo(tex, c, Color.WHITE if _lit.has(c) else Blocks.color(v), 0.11 if not _lit.has(c) else 0.22)
	for e in _clearing:
		var t: float = maxf(e["t"], 0.0)
		_halo(tex, e["cell"], Blocks.color(e["color"]), 0.6 * (1.0 - t / CLEAR_TIME))


func _halo(tex: Texture2D, c: Vector2i, col: Color, a: float) -> void:
	var r := cell * 0.95
	col.a = a
	_glow_layer.draw_texture_rect(tex, Rect2(cell_center(c) - Vector2(r, r), Vector2(r, r) * 2.0), false, col)
