extends RefCounted
## Hands out three pieces at a time. Fair, but generous often enough to keep
## the player hooked: at least one piece always fits, and now and then one of
## them is exactly what is needed to finish a line.

const Shapes := preload("res://scripts/game/shapes.gd")
const Blocks := preload("res://scripts/game/blocks.gd")
const Board := preload("res://scripts/game/board.gd")


static func deal(board: Board, rng: RandomNumberGenerator) -> Array:
	var crowded := board.filled() > Board.N * Board.N / 2
	var set: Array[int] = []
	for attempt in 40:
		set = []
		for i in 3:
			set.append(Shapes.random(rng, crowded))
		if set.any(func(s: int) -> bool: return board.fits_anywhere(Shapes.cells(s))):
			break
	if rng.randf() < (0.6 if crowded else 0.4):
		var help := _helpful(board)
		if help >= 0:
			set[rng.randi() % 3] = help
	var colors := range(1, Blocks.PALETTE.size() + 1)
	colors.shuffle()
	var out := []
	for i in 3:
		out.append({"shape": set[i], "color": colors[i]})
	return out


## A piece that fits somewhere and completes at least one line, or -1.
static func _helpful(board: Board) -> int:
	var order := range(Shapes.count())
	order.shuffle()
	for s in order:
		var shape := Shapes.cells(s)
		for y in Board.N:
			for x in Board.N:
				var p := Vector2i(x, y)
				if board.can_place(shape, p):
					var lines := board.lines_if_placed(shape, p)
					if lines["rows"].size() + lines["cols"].size() > 0:
						return s
	return -1
