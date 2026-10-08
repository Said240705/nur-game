extends RefCounted
## Every piece the dealer can hand out, drawn as little ASCII pictures, with how
## often it comes up. Small and friendly pieces are common, big ones rare.

const DEFS := [
	[3.0, "X"],
	[4.0, "XX"], [4.0, "X\nX"],
	[4.0, "XXX"], [4.0, "X\nX\nX"],
	[2.5, "XXXX"], [2.5, "X\nX\nX\nX"],
	[1.5, "XXXXX"], [1.5, "X\nX\nX\nX\nX"],
	[5.0, "XX\nXX"],
	[2.0, "XXX\nXXX"], [2.0, "XX\nXX\nXX"],
	[1.2, "XXX\nXXX\nXXX"],
	[3.0, "XX\nX."], [3.0, "XX\n.X"], [3.0, "X.\nXX"], [3.0, ".X\nXX"],
	[1.5, "X.\nX.\nXX"], [1.5, ".X\n.X\nXX"], [1.5, "XX\nX.\nX."], [1.5, "XX\n.X\n.X"],
	[1.5, "XXX\nX.."], [1.5, "XXX\n..X"], [1.5, "X..\nXXX"], [1.5, "..X\nXXX"],
	[1.5, "XXX\n.X."], [1.5, ".X.\nXXX"], [1.5, "X.\nXX\nX."], [1.5, ".X\nXX\n.X"],
	[1.0, ".XX\nXX."], [1.0, "XX.\n.XX"], [1.0, "X.\nXX\n.X"], [1.0, ".X\nXX\nX."],
	[1.0, "XXX\nX..\nX.."], [1.0, "XXX\n..X\n..X"], [1.0, "X..\nX..\nXXX"], [1.0, "..X\n..X\nXXX"],
]

static var _cells: Array = []
static var _bounds: Array[Vector2i] = []


static func _build() -> void:
	if not _cells.is_empty():
		return
	for d in DEFS:
		var rows: PackedStringArray = (d[1] as String).split("\n")
		var cells: Array[Vector2i] = []
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "X":
					cells.append(Vector2i(x, y))
		_cells.append(cells)
		_bounds.append(Vector2i(rows[0].length(), rows.size()))


static func count() -> int:
	_build()
	return _cells.size()


## The squares of piece `i`, as offsets from its top-left corner.
static func cells(i: int) -> Array[Vector2i]:
	_build()
	return _cells[i]


## Width and height of piece `i`, in squares.
static func bounds(i: int) -> Vector2i:
	_build()
	return _bounds[i]


## A piece picked by weight. On a crowded board big pieces turn up less often.
static func random(rng: RandomNumberGenerator, crowded := false) -> int:
	_build()
	var weights: Array[float] = []
	var total := 0.0
	for i in DEFS.size():
		var w: float = DEFS[i][0]
		if crowded and _cells[i].size() >= 5:
			w *= 0.35
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0
