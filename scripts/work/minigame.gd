extends Control
## Base of every job: a play area that pays per success. Subclasses draw in
## _draw(), move things in step() and react to touches in tap().
## Work stops while a card covers the screen or the tab is hidden.

## Money made (negative for a fine) and where on screen it happened.
signal earned(amount: float, at: Vector2, note: String)

const UI := preload("res://scripts/ui/ui.gd")
const GREEN := Color("#3ee08f")
const RED := Color("#ff5c6c")

var pay := 3.0
var _font: Font
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = UI.font(800)
	setup()


func active() -> bool:
	return is_visible_in_tree() and not UI.modal_open


func _process(delta: float) -> void:
	if active():
		_t += delta
		step(delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and active():
		tap(event.position)
		accept_event()


func setup() -> void:
	pass


func step(_delta: float) -> void:
	pass


func tap(_p: Vector2) -> void:
	pass


## Reports money to the game; `at` is local to this area.
func give(amount: float, at: Vector2, note := "") -> void:
	earned.emit(amount, get_global_transform() * at, note)


func text(t: String, center: Vector2, size_px: int, col: Color, weight := 800) -> void:
	var f := UI.font(weight)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string(f, Vector2(center.x - w * 0.5, center.y + size_px * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


## The one-line rule of the job on a dark strip across the top.
func hint(t: String) -> void:
	draw_rect(Rect2(0, 0, size.x, 72), Color(0, 0, 0, 0.45))
	text(t, Vector2(size.x * 0.5, 36), 30, Color.WHITE, 700)


func rounded(r: Rect2, col: Color, radius := 24, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	draw_style_box(sb, r)


## A simple person seen from the side: legs, coat, head, optional cap.
func person(feet: Vector2, coat: Color, walking: bool, phase: float, cap := Color(0, 0, 0, 0), scale_k := 1.0) -> void:
	var k := scale_k
	var step_v := sin(phase) if walking else 0.0
	var hip := feet + Vector2(0, -60 * k)
	draw_line(hip + Vector2(-8, 0) * k, feet + Vector2(-8 + step_v * 14, 0) * k + Vector2(0, 0), Color("#2b2d42"), 12 * k)
	draw_line(hip + Vector2(8, 0) * k, feet + Vector2(8 - step_v * 14, 0) * k, Color("#2b2d42"), 12 * k)
	rounded(Rect2(hip + Vector2(-24, -78) * k, Vector2(48, 84) * k), coat, int(16 * k))
	var head := hip + Vector2(0, -100) * k
	draw_circle(head, 22 * k, Color("#f2c19b"))
	if cap.a > 0.0:
		draw_rect(Rect2(head + Vector2(-24, -26) * k, Vector2(48, 16) * k), cap)
		draw_rect(Rect2(head + Vector2(-10, -24) * k, Vector2(20, 10) * k), Color("#ffd447"))
	else:
		draw_arc(head + Vector2(0, -4) * k, 22 * k, PI, TAU, 12, Color("#3b2a20"), 10 * k)
