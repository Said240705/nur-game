extends Control
## One round: the board, the tray of three pieces, dragging and dropping,
## clearing lines, score, combos and the end of the round.
## Lines pay more the more you clear at once, and clearing again within three
## moves keeps a combo going that multiplies everything.

signal finished(score: int, record: bool)

const Board := preload("res://scripts/game/board.gd")
const Shapes := preload("res://scripts/game/shapes.gd")
const Dealer := preload("res://scripts/game/dealer.gd")
const Blocks := preload("res://scripts/game/blocks.gd")
const BoardView := preload("res://scripts/game/board_view.gd")
const Fx := preload("res://scripts/game/fx.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Save := preload("res://scripts/save.gd")

const TRAY_SCALE := 0.52
## How far above the finger a dragged piece floats, so the finger never hides it.
const LIFT := 270.0
const LINE_POINTS := [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 5500, 6600, 7800, 9100, 10500, 12000, 13600]
const CLEAN_BONUS := 3000
const WORDS := ["", "", "Отлично!", "Супер!", "Невероятно!"]

var board := Board.new()
var view: BoardView
var fx: Fx
var pieces: Array = []
var score := 0
var best := 0
var streak := 0
var since_clear := 0
var over := false
## Set while a modal screen is up: the board ignores touches.
var paused := true

var _shown := 0.0
var _record := false
var _drag := -1
var _target := Vector2.ZERO
var _ghost_at := Vector2i(-1, -1)
var _ghost_ok := false
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _score: Label
var _best: Label
var _tray: Control
var _tray_y := 0.0
var _combo: Label
## Shown until the player clears a first line.
var _hint: Label
## When the word on screen is gone, so the next one waits its turn.
var _word_free_at := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	view = BoardView.new()
	add_child(view)
	_tray = Control.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tray.draw.connect(_draw_pieces)
	add_child(_tray)
	fx = Fx.new()
	add_child(fx)

	_score = UI.label("0", 120, UI.TEXT, 800)
	UI.glow(_score, Color(0.75, 0.55, 1.0, 0.55), 22)
	add_child(_score)
	_best = UI.label("", 40, UI.GOLD, 700)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_best)
	_combo = UI.label("", 44, UI.GOLD, 800)
	_combo.modulate.a = 0.0
	add_child(_combo)
	_hint = UI.label("Заполни ряд или столбец целиком —\nон взорвётся. Цвет не важен.", 40, UI.SUB, 500)
	_hint.visible = not Save.get_value("learned", false)
	add_child(_hint)
	best = Save.get_value("best", 0)
	resized.connect(_layout)


## Lays everything out for the current screen height (phones differ in length).
func _layout() -> void:
	var w := size.x
	var h := size.y
	var board_w := w - 64.0
	view.setup(board, board_w)
	var extra := maxf(0.0, h - 1920.0)
	view.position = Vector2(32, 380 + extra * 0.35)
	_score.position = Vector2(0, 170 + extra * 0.25)
	_score.size = Vector2(w, 150)
	_best.position = Vector2(150, 70 + extra * 0.15)
	_best.size = Vector2(500, 60)
	_combo.position = Vector2(0, view.position.y - 70)
	_combo.size = Vector2(w, 60)
	_tray.size = size
	fx.size = size
	_tray_y = view.position.y + board_w + (h - view.position.y - board_w) * 0.47
	_hint.position = Vector2(0, view.position.y + board_w + 24)
	_hint.size = Vector2(w, 110)
	queue_redraw()


func new_round() -> void:
	board = Board.new()
	view.board = board
	view.reset()
	score = 0
	_shown = 0.0
	streak = 0
	since_clear = 0
	over = false
	_record = false
	_deal()
	_save()


## Picks up a saved round; false if there is none.
func restore() -> bool:
	var st: Dictionary = Save.get_value("round", {})
	if st.is_empty():
		return false
	board = Board.new()
	board.cells = PackedInt32Array(st["cells"])
	view.board = board
	view.reset()
	score = st["score"]
	_shown = score
	streak = st["streak"]
	since_clear = st["since"]
	over = false
	_record = false
	pieces = []
	for p in st["pieces"]:
		pieces.append({"shape": p[0], "color": p[1], "placed": p[2], "pos": Vector2.ZERO, "scale": TRAY_SCALE})
	for i in 3:
		pieces[i]["pos"] = _slot(i)
	return true


func _save() -> void:
	if over:
		Save.set_value("round", {})
		return
	var ps := []
	for p in pieces:
		ps.append([p["shape"], p["color"], p["placed"]])
	Save.set_value("round", {"cells": Array(board.cells), "score": score, "streak": streak, "since": since_clear, "pieces": ps})


func _deal() -> void:
	pieces = []
	var set := Dealer.deal(board, _rng)
	for i in 3:
		var p: Dictionary = set[i]
		# New pieces slide in from the right, one after another.
		pieces.append({"shape": p["shape"], "color": p["color"], "placed": false,
			"pos": _slot(i) + Vector2(size.x + i * 260.0, 0), "scale": TRAY_SCALE})
	Sfx.play("deal", -10.0)


func _slot(i: int) -> Vector2:
	return Vector2(size.x * (i * 2 + 1) / 6.0, _tray_y)


# --- Touch ------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if paused or over or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := make_input_local(event) as InputEventScreenTouch
		if e.pressed and _drag < 0:
			for i in 3:
				var hit := Rect2(_slot(i) - Vector2(size.x / 6.0, 190), Vector2(size.x / 3.0, 380))
				if not pieces[i]["placed"] and hit.has_point(e.position):
					_drag = i
					_move(e.position)
					Sfx.play("pick", -6.0)
					break
		elif not e.pressed and _drag >= 0:
			_drop()
	elif event is InputEventScreenDrag and _drag >= 0:
		_move((make_input_local(event) as InputEventScreenDrag).position)


func _move(finger: Vector2) -> void:
	_target = finger + Vector2(0, -LIFT)
	var p: Dictionary = pieces[_drag]
	var shape := Shapes.cells(p["shape"])
	var top_left := _target - _piece_size(p["shape"], 1.0) * 0.5 - view.position
	_ghost_at = view.grid_at(top_left)
	_ghost_ok = board.can_place(shape, _ghost_at)
	if _ghost_ok:
		view.show_ghost(shape, _ghost_at, p["color"], board.lines_if_placed(shape, _ghost_at))
	else:
		view.hide_ghost()


func _drop() -> void:
	var i := _drag
	_drag = -1
	view.hide_ghost()
	if _ghost_ok:
		_place(i, _ghost_at)
	else:
		Sfx.play("miss", -8.0)
	_ghost_ok = false


# --- Rules --------------------------------------------------------------------

func _place(i: int, at: Vector2i) -> void:
	var p: Dictionary = pieces[i]
	var shape := Shapes.cells(p["shape"])
	board.place(shape, at, p["color"])
	p["placed"] = true
	var landed := []
	var middle := Vector2.ZERO
	for o in shape:
		landed.append(at + o)
		middle += Vector2(at + o)
	middle /= shape.size()
	view.popped(landed)
	Sfx.play("place", -2.0, _rng.randf_range(0.95, 1.05))
	Input.vibrate_handheld(12)

	var gained := shape.size() * 10
	var lines := board.full_lines()
	var n: int = lines["rows"].size() + lines["cols"].size()
	var spot := view.position + view.cell_center(Vector2i(roundi(middle.x), roundi(middle.y)))
	if n > 0:
		if _hint.visible:
			Save.set_value("learned", true)
			_hint.create_tween().tween_property(_hint, "modulate:a", 0.0, 0.6).finished.connect(_hint.hide)
		streak += 1
		since_clear = 0
		var gone := board.clear(lines)
		view.cleared(gone, middle)
		for g in gone:
			fx.burst(view.position + view.cell_center(g[0]), Blocks.color(g[1]), 4)
		gained += LINE_POINTS[mini(n, LINE_POINTS.size() - 1)] * streak
		Sfx.play("clear", -4.0, 1.0 + 0.07 * mini(streak - 1, 8))
		if n >= 2:
			Sfx.play("big", -2.0)
		_shake = 8.0 + n * 5.0
		Input.vibrate_handheld(35)
		if n >= 2:
			_word(WORDS[mini(n, WORDS.size() - 1)], Blocks.color(p["color"]))
		if streak >= 2:
			_show_combo()
		if board.filled() == 0:
			gained += CLEAN_BONUS
			_word("Чисто!", UI.GOLD)
	else:
		since_clear += 1
		if since_clear >= 3:
			streak = 0
			_combo.create_tween().tween_property(_combo, "modulate:a", 0.0, 0.4)
	score += gained
	_popup("+" + UI.number(gained), spot, 64 if n > 0 else 44)
	if score > best:
		best = score
		Save.set_value("best", best)
		_record = true
	if pieces.all(func(q: Dictionary) -> bool: return q["placed"]):
		_deal()
	_check_over()
	_save()


func _check_over() -> void:
	for p in pieces:
		if not p["placed"] and board.fits_anywhere(Shapes.cells(p["shape"])):
			return
	over = true
	_save()
	await get_tree().create_timer(0.7).timeout
	view.turn_to_stone()
	Sfx.play("over", -4.0)
	await get_tree().create_timer(1.3).timeout
	finished.emit(score, _record)


# --- Feedback -------------------------------------------------------------------

func _popup(text: String, at: Vector2, size_px: int) -> void:
	var l := UI.label(text, size_px, Color.WHITE, 800)
	UI.glow(l, Color(1, 0.85, 0.4, 0.7), 14)
	l.size = Vector2(500, 100)
	l.position = at - l.size * 0.5
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 150, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


## A big word in the middle of the board: «Отлично!», «Супер!», «Чисто!».
func _word(text: String, color: Color) -> void:
	var l := UI.label(text, 120, Color.WHITE, 900)
	UI.glow(l, Color(color, 0.9), 26)
	l.size = Vector2(size.x, 200)
	l.position = Vector2(0, view.position.y + view.size.y * 0.5 - 100)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(0.4, 0.4)
	l.modulate.a = 0.0
	add_child(l)
	var now := Time.get_ticks_msec() / 1000.0
	var delay := maxf(0.0, _word_free_at - now)
	_word_free_at = now + delay + 1.0
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.01)
	tw.tween_property(l, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func _show_combo() -> void:
	_combo.text = "Комбо ×%d" % streak
	UI.glow(_combo, Color(1, 0.6, 0.2, 0.7), 16)
	_combo.modulate.a = 1.0
	_combo.pivot_offset = _combo.size * 0.5
	_combo.scale = Vector2(1.4, 1.4)
	_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


# --- Frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	# The score counts up instead of jumping.
	_shown = move_toward(_shown, score, maxf(40.0, (score - _shown) * 6.0) * delta)
	_score.text = UI.number(int(_shown))
	_best.text = UI.number(best)
	if _shake > 0.0:
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = move_toward(_shake, 0.0, delta * 60.0)
		if _shake == 0.0:
			position = Vector2.ZERO
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		var dragging := i == _drag
		var goal: Vector2 = _target if dragging else _slot(i)
		var rate := 40.0 if dragging else 13.0
		p["pos"] = (p["pos"] as Vector2).lerp(goal, 1.0 - exp(-rate * delta))
		p["scale"] = lerpf(p["scale"], 1.0 if dragging else TRAY_SCALE, 1.0 - exp(-22.0 * delta))
	_tray.queue_redraw()
	queue_redraw()


func _piece_size(shape: int, s: float) -> Vector2:
	var b := Shapes.bounds(shape)
	return Vector2(b.x * view.pitch() - BoardView.GAP, b.y * view.pitch() - BoardView.GAP) * s


func _draw() -> void:
	# A crown before the best score.
	var c := _best.position + Vector2(-58, 30)
	var pts := PackedVector2Array([c + Vector2(-26, 14), c + Vector2(-30, -16), c + Vector2(-12, -2), c + Vector2(0, -22),
		c + Vector2(12, -2), c + Vector2(30, -16), c + Vector2(26, 14)])
	draw_colored_polygon(pts, UI.GOLD)


func _draw_pieces() -> void:
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if p["placed"]:
			continue
		var s: float = p["scale"]
		var dim := 1.0
		if not over and i != _drag and not board.fits_anywhere(Shapes.cells(p["shape"])):
			dim = 0.35
		var top_left: Vector2 = p["pos"] - _piece_size(p["shape"], s) * 0.5
		var cell := view.cell * s
		var pitch := view.pitch() * s
		for o in Shapes.cells(p["shape"]):
			var r := Rect2(top_left + Vector2(o) * pitch, Vector2(cell, cell))
			_tray.draw_texture_rect(Blocks.block(p["color"]), r, false, Color(dim, dim, dim, 1.0 if dim == 1.0 else 0.7))
