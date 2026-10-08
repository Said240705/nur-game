extends RefCounted
## The 8×8 board as plain data: which squares are filled and with what colour
## (0 is empty). Knows where a piece fits and which lines are full.

const N := 8

var cells := PackedInt32Array()


func _init() -> void:
	cells.resize(N * N)


func at(c: Vector2i) -> int:
	return cells[c.y * N + c.x]


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


func can_place(shape: Array[Vector2i], pos: Vector2i) -> bool:
	for o in shape:
		var c := pos + o
		if not inside(c) or cells[c.y * N + c.x] != 0:
			return false
	return true


func place(shape: Array[Vector2i], pos: Vector2i, color: int) -> void:
	for o in shape:
		var c := pos + o
		cells[c.y * N + c.x] = color


## Full rows and columns: {"rows": [...], "cols": [...]}.
func full_lines() -> Dictionary:
	var rows: Array[int] = []
	var cols: Array[int] = []
	for i in N:
		var row_full := true
		var col_full := true
		for j in N:
			if cells[i * N + j] == 0:
				row_full = false
			if cells[j * N + i] == 0:
				col_full = false
		if row_full:
			rows.append(i)
		if col_full:
			cols.append(i)
	return {"rows": rows, "cols": cols}


## The lines that would be full if the piece were dropped here.
func lines_if_placed(shape: Array[Vector2i], pos: Vector2i) -> Dictionary:
	var saved := cells.duplicate()
	place(shape, pos, 1)
	var lines := full_lines()
	cells = saved
	return lines


## Empties the given lines; returns what was there as [[Vector2i, colour], ...].
func clear(lines: Dictionary) -> Array:
	var gone := {}
	for r in lines["rows"]:
		for x in N:
			gone[Vector2i(x, r)] = true
	for c in lines["cols"]:
		for y in N:
			gone[Vector2i(c, y)] = true
	var out := []
	for c in gone:
		out.append([c, at(c)])
		cells[c.y * N + c.x] = 0
	return out


func fits_anywhere(shape: Array[Vector2i]) -> bool:
	for y in N:
		for x in N:
			if can_place(shape, Vector2i(x, y)):
				return true
	return false


func filled() -> int:
	var n := 0
	for v in cells:
		if v != 0:
			n += 1
	return n
