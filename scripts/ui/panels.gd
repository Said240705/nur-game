extends CanvasLayer
## Film frames for the cutscenes: a big illustration the camera slowly drifts
## across (portrait screen, landscape art), graded to one look, with rain
## running over it and Lev's inner voice as subtitles.

const GRADE := preload("res://shaders/grade.gdshader")
const VIEW := Vector2(1080, 1920)

var _frame: Control
var _image: TextureRect
var _rain: Control
var _voice: Label
var _drops: Array = []
var _tapped := false


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.clip_contents = true
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.add_child(black)

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_SCALE
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRADE
	_image.material = mat
	_frame.add_child(_image)

	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	_frame.add_child(_rain)
	for i in 140:
		_drops.append([Vector2(randf() * 1300 - 100, randf() * 2000), randf_range(1800, 2600), randf_range(40, 90)])

	var shade := TextureRect.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.85)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -620
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(shade)

	_voice = Label.new()
	_voice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_voice.offset_top = -480
	_voice.offset_bottom = -220
	_voice.offset_left = 80
	_voice.offset_right = -80
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_voice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice.add_theme_font_size_override("font_size", 50)
	_voice.add_theme_color_override("font_color", Color(0.96, 0.92, 0.85))
	_voice.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_voice.add_theme_constant_override("shadow_offset_y", 3)
	_voice.add_theme_constant_override("line_spacing", 10)
	_voice.modulate.a = 0.0
	_frame.add_child(_voice)


func _input(event: InputEvent) -> void:
	if visible and ((event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed)):
		_tapped = true


func _process(delta: float) -> void:
	if not visible:
		return
	for d in _drops:
		var p: Vector2 = d[0]
		p += Vector2(0.12, 1.0) * d[1] * delta
		if p.y > 2000:
			p = Vector2(randf() * 1300 - 200, -100)
		d[0] = p
	_rain.queue_redraw()


func _draw_rain() -> void:
	for d in _drops:
		var p: Vector2 = d[0]
		_rain.draw_line(p, p + Vector2(0.12, 1.0) * d[2], Color(0.75, 0.85, 1.0, 0.16), 2.0)


## Show a frame and drift across it. `from`/`to` are focus points in 0..1 of the
## image; `zoom` scales the image beyond "cover the screen".
func shot(tex: Texture2D, from: Vector2, to: Vector2, seconds: float, zoom_from := 1.0, zoom_to := 1.08) -> void:
	visible = true
	_image.texture = tex
	_image.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_image, "modulate:a", 1.0, 1.2)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float) -> void: _frame_at(tex, from.lerp(to, k), lerpf(zoom_from, zoom_to, k)), 0.0, 1.0, seconds)
	_frame_at(tex, from, zoom_from)


func _frame_at(tex: Texture2D, focus: Vector2, zoom: float) -> void:
	var cover := maxf(VIEW.x / tex.get_width(), VIEW.y / tex.get_height()) * zoom
	var size := tex.get_size() * cover
	var pos := VIEW * 0.5 - size * focus
	pos.x = clampf(pos.x, VIEW.x - size.x, 0.0)
	pos.y = clampf(pos.y, VIEW.y - size.y, 0.0)
	_image.size = size
	_image.position = pos


## Lev's inner voice; waits for the given time or a tap.
func say(text: String, seconds := 3.2) -> void:
	_voice.text = text
	var tw := create_tween()
	tw.tween_property(_voice, "modulate:a", 1.0, 0.6)
	await tw.finished
	_tapped = false
	var t := 0.0
	while t < seconds and not _tapped:
		await get_tree().process_frame
		t += get_process_delta_time()
	tw = create_tween()
	tw.tween_property(_voice, "modulate:a", 0.0, 0.5)
	await tw.finished


func hide_frames(seconds := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_image, "modulate:a", 0.0, seconds)
	await tw.finished
	visible = false
