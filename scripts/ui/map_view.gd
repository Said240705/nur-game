extends Control
## The city map: six districts around a river, streets, a park and the places
## for rent. Free places show a "+" and their size; yours show the business.

signal plot_tapped(id: int)

const Data := preload("res://scripts/game/data.gd")
const Venue := preload("res://scripts/game/venue.gd")
const Icons := preload("res://scripts/ui/icons.gd")
const UI := preload("res://scripts/ui/ui.gd")
const MAP := Vector2(1000, 1300)
## District areas on the map.
const AREAS := {
	"embankment": Rect2(0, 60, 560, 380),
	"business": Rect2(580, 60, 420, 420),
	"campus": Rect2(0, 500, 410, 360),
	"center": Rect2(420, 500, 580, 360),
	"outskirts": Rect2(0, 870, 490, 430),
	"sleepy": Rect2(500, 870, 500, 430),
}

var state: RefCounted
var _t := 0.0
var _blocks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Houses scattered over the districts, kept away from the places for rent.
	for d in AREAS:
		var a: Rect2 = AREAS[d]
		for i in 26:
			var r := Rect2(a.position + Vector2(rng.randf_range(20, a.size.x - 80), rng.randf_range(40, a.size.y - 70)),
				Vector2(rng.randf_range(34, 70), rng.randf_range(30, 60)))
			var clear := true
			for p in Data.PLOTS:
				if r.grow(36).has_point(p["pos"]):
					clear = false
			if clear:
				_blocks.append([r, d])


func _scale() -> float:
	return minf(size.x / MAP.x, size.y / MAP.y)


func _origin() -> Vector2:
	return (size - MAP * _scale()) * 0.5


func _to_screen(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not UI.modal_open:
		var best := -1
		var best_d := 70.0 * maxf(_scale(), 0.8)
		for p in Data.PLOTS:
			var d: float = event.position.distance_to(_to_screen(p["pos"]))
			if d < best_d:
				best_d = d
				best = p["id"]
		if best >= 0:
			Sfx.play("click")
			plot_tapped.emit(best)


func _draw() -> void:
	var k := _scale()
	draw_set_transform(_origin(), 0.0, Vector2(k, k))
	draw_rect(Rect2(Vector2.ZERO, MAP), Color("#1c2230"))
	for d in AREAS:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Data.DISTRICTS[d]["color"]
		sb.set_corner_radius_all(40)
		draw_style_box(sb, AREAS[d].grow(-6))
	for b in _blocks:
		var col: Color = Data.DISTRICTS[b[1]]["color"].lightened(0.18)
		draw_rect(b[0], col)
		draw_rect(Rect2(b[0].position, Vector2(b[0].size.x, 8)), col.lightened(0.15))
	# The river with two bridges.
	var river := PackedVector2Array()
	for i in 21:
		var x := i * 50.0
		river.append(Vector2(x, 470 + sin(x / 130.0) * 14))
	draw_polyline(river, Color("#2d6f9e"), 46, true)
	draw_polyline(river, Color("#3f8fc4"), 30, true)
	for bx in [300.0, 760.0]:
		draw_rect(Rect2(bx - 26, 440, 52, 64), Color("#8a8f9e"))
	# Main streets.
	for x in [415.0, 495.0]:
		draw_line(Vector2(x, 500), Vector2(x, 1300), Color(1, 1, 1, 0.12), 14)
	draw_line(Vector2(0, 865), Vector2(1000, 865), Color(1, 1, 1, 0.12), 14)
	draw_line(Vector2(570, 60), Vector2(570, 440), Color(1, 1, 1, 0.12), 14)
	# A park in the centre.
	draw_circle(Vector2(930, 800), 46, Color("#3f7a45"))
	for i in 5:
		draw_circle(Vector2(930, 800) + Vector2.from_angle(i * 1.25) * 24, 12, Color("#2f6034"))
	var f := UI.font(800)
	for d in AREAS:
		var a: Rect2 = AREAS[d]
		var name: String = Data.DISTRICTS[d]["name"]
		draw_string(f, a.position + Vector2(26, 46), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.8))
		Icons.stars(self, a.position + Vector2(26, 72), Data.DISTRICTS[d]["wealth"], Data.DISTRICTS[d]["wealth"], 10)
	for p in Data.PLOTS:
		_draw_plot(p)
	draw_set_transform(Vector2.ZERO)


func _draw_plot(p: Dictionary) -> void:
	var c: Vector2 = p["pos"]
	var v: Dictionary = state.venue_at(p["id"])
	var r := {"S": 34.0, "M": 42.0, "L": 50.0}[p["size"]] as float
	if v.is_empty():
		var pulse := 0.5 + 0.5 * sin(_t * 3.0 + p["id"])
		draw_circle(c, r + 6 + pulse * 4, Color(1, 1, 1, 0.12))
		draw_circle(c, r, Color(1, 1, 1, 0.92))
		draw_line(c - Vector2(14, 0), c + Vector2(14, 0), Color("#1c2230"), 6)
		draw_line(c - Vector2(0, 14), c + Vector2(0, 14), Color("#1c2230"), 6)
		var f := UI.font(800)
		var t: String = p["size"]
		draw_string(f, c + Vector2(r * 0.55, -r * 0.55), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ffd447"))
	else:
		var b := Venue.kind(v)
		var size := r * 2.2
		Icons.tile(self, b["id"], Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), b["color"])
		# A red dot when the place cannot work.
		if Venue.blocker(v) != "":
			draw_circle(c + Vector2(size * 0.45, -size * 0.45), 14, Color("#ff5c6c"))
			draw_circle(c + Vector2(size * 0.45, -size * 0.45), 5, Color.WHITE)
