extends SceneTree
## Checks the board rules without a screen:
##   godot --headless --script res://scripts/dev/test_rules.gd

const Board := preload("res://scripts/game/board.gd")
const Shapes := preload("res://scripts/game/shapes.gd")
const Dealer := preload("res://scripts/game/dealer.gd")

var _failed := 0


func _init() -> void:
	var b := Board.new()
	var bar5: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	var bar3: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	_check(b.can_place(bar5, Vector2i(3, 0)), "a 5-bar fits at the right edge")
	_check(not b.can_place(bar5, Vector2i(4, 0)), "a 5-bar does not stick out of the board")
	b.place(bar5, Vector2i(0, 7), 1)
	_check(not b.can_place(bar3, Vector2i(4, 7)), "pieces do not overlap")
	var lines := b.lines_if_placed(bar3, Vector2i(5, 7))
	_check(lines["rows"] == [7] and lines["cols"].is_empty(), "completing row 7 is predicted")
	_check(b.at(Vector2i(6, 7)) == 0, "predicting does not change the board")
	b.place(bar3, Vector2i(5, 7), 2)
	var gone := b.clear(b.full_lines())
	_check(gone.size() == 8 and b.filled() == 0, "a full row clears all eight squares")
	# A row and a column sharing a corner clear 15 squares, not 16.
	for i in 8:
		b.cells[7 * 8 + i] = 3
		b.cells[i * 8 + 0] = 3
	var both := b.full_lines()
	_check(both["rows"] == [7] and both["cols"] == [0], "row and column found together")
	_check(b.clear(both).size() == 15, "the shared corner is counted once")
	# The dealer always hands out at least one piece that fits.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var crowded := Board.new()
	for i in 64:
		crowded.cells[i] = 1 if i % 9 != 0 else 0
	for round in 50:
		var set := Dealer.deal(crowded, rng)
		var fits := set.any(func(p: Dictionary) -> bool: return crowded.fits_anywhere(Shapes.cells(p["shape"])))
		if not fits:
			_check(false, "dealer gave a set where nothing fits")
			break
	_check(Shapes.count() == Shapes.DEFS.size(), "every shape parses")
	print("FAILED: %d" % _failed if _failed else "ALL PASSED")
	quit(1 if _failed else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
		print("FAIL: ", what)
