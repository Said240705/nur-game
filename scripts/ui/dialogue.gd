extends CanvasLayer
## Conversation box: Nur's painted portrait, the speaker's name and a typewriter line.
## play() runs a whole conversation and returns when the last line is dismissed.

const PORTRAITS := {
	"calm": preload("res://assets/art/nur/face_calm.png"),
	"sad": preload("res://assets/art/nur/face_sad.png"),
	"surprised": preload("res://assets/art/nur/face_surprised.png"),
	"determined": preload("res://assets/art/nur/face_determined.png"),
}
const CHARS_PER_SECOND := 38.0
const NAME_COLOR := Color(1.0, 0.74, 0.45)

var _root: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _more: Label
var _tapped := false
var _typing := false
var _t := 0.0


func _ready() -> void:
	# Above the cinema layer, so the box sits over the letterbox bars in cutscenes.
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -270.0
	_panel.offset_bottom = -30.0
	_panel.offset_left = 120.0
	_panel.offset_right = -120.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.1, 0.86)
	box.border_color = Color(1.0, 0.74, 0.45, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.content_margin_left = 40
	box.content_margin_right = 40
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", box)
	_root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 34)
	_name.add_theme_color_override("font_color", NAME_COLOR)
	v.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 40)
	_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	_text.add_theme_constant_override("line_spacing", 8)
	v.add_child(_text)

	_more = Label.new()
	_more.text = "▼"
	_more.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_more.offset_left = -200.0
	_more.offset_top = -100.0
	_more.offset_right = -160.0
	_more.offset_bottom = -50.0
	_more.add_theme_font_size_override("font_size", 28)
	_more.add_theme_color_override("font_color", NAME_COLOR)
	_root.add_child(_more)

	# The portrait stands on the box's left edge, like in a picture book.
	_portrait = TextureRect.new()
	_portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.offset_left = 70.0
	_portrait.offset_right = 380.0
	_portrait.offset_top = -720.0
	_portrait.offset_bottom = -250.0
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if pressed:
		_tapped = true
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_more.visible = _root.visible and not _typing
	_more.modulate.a = 0.5 + 0.5 * sin(_t * 4.0)


## Plays a list of [speaker, text, portrait] lines.
func play(lines: Array) -> void:
	_root.visible = true
	_root.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 1.0, 0.25)
	for line in lines:
		await _show(line[0], line[1], line[2])
	tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	await tw.finished
	_root.visible = false


func _show(speaker: String, text: String, portrait: String) -> void:
	_name.text = speaker
	_name.visible = speaker != ""
	_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97) if speaker != "" else Color(0.78, 0.84, 0.98))
	_portrait.texture = PORTRAITS.get(portrait)
	_portrait.visible = _portrait.texture != null
	_panel.offset_left = 400.0 if _portrait.visible else 120.0
	_text.text = text
	_text.visible_characters = 0
	_typing = true
	_tapped = false
	var shown := 0.0
	while shown < text.length() and not _tapped:
		await get_tree().process_frame
		shown += get_process_delta_time() * CHARS_PER_SECOND
		_text.visible_characters = int(shown)
	_text.visible_characters = -1
	_typing = false
	_tapped = false
	while not _tapped:
		await get_tree().process_frame
