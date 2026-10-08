extends Node
## СИЯНИЕ: the night sky, the game, the title card and the end-of-round card,
## and the sound and music switches.

const Background := preload("res://scripts/game/background.gd")
const Game := preload("res://scripts/game/game.gd")
const Blocks := preload("res://scripts/game/blocks.gd")
const UI := preload("res://scripts/ui/ui.gd")
const Save := preload("res://scripts/save.gd")

const TITLE := "СИЯНИЕ"

var root: Control
var game: Game
var _card: Control
var _toggles: Control


func _ready() -> void:
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Background.new()
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game = Game.new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.finished.connect(_on_finished)
	Sfx.sound_on = Save.get_value("sound", true)
	Sfx.music_on = Save.get_value("music", true)
	_build_toggles()

	var dev := OS.get_cmdline_user_args()
	await get_tree().process_frame
	var resumed := game.restore()
	if not resumed:
		game.new_round()
	if dev.size() > 0:
		var tool: Node = load("res://scripts/dev/autoshot.gd").new()
		tool.setup(self, dev)
		add_child(tool)
		return
	_title(resumed)


# --- Title ----------------------------------------------------------------------

func _title(resumed: bool) -> void:
	var card := _new_card(0.5)
	var box := _column(card, 0.3)
	var logo := UI.label(TITLE, 170, Color.WHITE, 900)
	UI.glow(logo, Color(0.7, 0.45, 1.0, 0.85), 34)
	box.add_child(logo)
	box.add_child(_gem_row())
	box.add_child(UI.label("головоломка из сияющих блоков", 44, UI.SUB, 500))
	box.add_child(_spacer(90))
	var best: int = Save.get_value("best", 0)
	if best > 0:
		var b := UI.label("Рекорд  " + UI.number(best), 52, UI.GOLD, 700)
		UI.glow(b, Color(1, 0.75, 0.2, 0.5), 12)
		box.add_child(b)
		box.add_child(_spacer(50))
	box.add_child(_centered(UI.pill_button("Продолжить" if resumed else "Играть", UI.GOLD, _start)))
	if resumed:
		box.add_child(_spacer(30))
		var b := Button.new()
		b.text = "Новая игра"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(500, 110)
		b.add_theme_font_override("font", UI.font(600))
		b.add_theme_font_size_override("font_size", 46)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, UI.SUB)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			game.new_round()
			_start())
		box.add_child(_centered(b))
	_show_card(card)


func _start() -> void:
	Sfx.set_music(Sfx.music_on)
	await _hide_card()
	game.paused = false


# --- End of round -------------------------------------------------------------

func _on_finished(score: int, record: bool) -> void:
	game.paused = true
	var card := _new_card(0.62)
	var box := _column(card, 0.27)
	box.add_child(UI.label("Ходов больше нет", 54, UI.SUB, 600))
	box.add_child(_spacer(30))
	var s := UI.label(UI.number(score), 190, Color.WHITE, 900)
	UI.glow(s, Color(0.7, 0.45, 1.0, 0.85), 30)
	box.add_child(s)
	box.add_child(_spacer(30))
	if record:
		var r := UI.label("Новый рекорд!", 70, UI.GOLD, 800)
		UI.glow(r, Color(1, 0.7, 0.2, 0.8), 22)
		box.add_child(r)
	else:
		box.add_child(UI.label("Рекорд  " + UI.number(Save.get_value("best", 0)), 52, UI.GOLD, 700))
	box.add_child(_spacer(110))
	box.add_child(_centered(UI.pill_button("Ещё раз", UI.GOLD, func() -> void:
		game.new_round()
		_start())))
	_show_card(card)
	if record:
		Sfx.play("record", -2.0)
		game.fx.confetti(root.size.x)


# --- Cards ----------------------------------------------------------------------

func _new_card(dim: float) -> Control:
	var card := Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.1, dim)
	card.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return card


func _column(card: Control, top: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = root.size.y * top - 200
	return box


func _show_card(card: Control) -> void:
	_card = card
	root.add_child(card)
	root.move_child(_toggles, -1)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.45)


func _hide_card() -> void:
	if not _card:
		return
	var card := _card
	_card = null
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.35)
	await tw.finished
	card.queue_free()


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _centered(c: Control) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.add_child(c)
	return holder


## Four little gems under the logo.
func _gem_row() -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.draw.connect(func() -> void:
		var n := 5
		var s := 74.0
		var x0 := (row.size.x - n * s - (n - 1) * 12.0) * 0.5
		for i in n:
			var bob := sin(Time.get_ticks_msec() / 400.0 + i * 0.9) * 6.0
			row.draw_texture_rect(Blocks.block(i * 2 % Blocks.PALETTE.size() + 1), Rect2(x0 + i * (s + 12.0), 18 + bob, s, s), false))
	var timer := Timer.new()
	timer.wait_time = 1.0 / 30.0
	timer.autostart = true
	timer.timeout.connect(row.queue_redraw)
	row.add_child(timer)
	return row


# --- Sound and music switches -------------------------------------------------

func _build_toggles() -> void:
	_toggles = Control.new()
	_toggles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toggles)
	_toggles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for kind in ["music", "sound"]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(104, 104)
		b.size = b.custom_minimum_size
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08)
		sb.set_corner_radius_all(52)
		sb.anti_aliasing = true
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		var right := -26.0 if kind == "sound" else -150.0
		b.offset_left = right - 104.0
		b.offset_right = right
		b.offset_top = 46
		b.offset_bottom = 150
		b.draw.connect(_draw_toggle.bind(b, kind))
		b.pressed.connect(func() -> void:
			if kind == "sound":
				Sfx.sound_on = not Sfx.sound_on
				Save.set_value("sound", Sfx.sound_on)
			else:
				Sfx.set_music(not Sfx.music_on)
				Save.set_value("music", Sfx.music_on)
			Sfx.play("click")
			b.queue_redraw())
		_toggles.add_child(b)


func _draw_toggle(b: Button, kind: String) -> void:
	var on: bool = Sfx.sound_on if kind == "sound" else Sfx.music_on
	var col := Color(1, 1, 1, 0.9 if on else 0.35)
	var c := Vector2(52, 52)
	if kind == "sound":
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -9), c + Vector2(-10, -9), c + Vector2(4, -22),
			c + Vector2(4, 22), c + Vector2(-10, 9), c + Vector2(-22, 9)]), col)
		if on:
			b.draw_arc(c + Vector2(4, 0), 14, -0.9, 0.9, 12, col, 4, true)
			b.draw_arc(c + Vector2(4, 0), 24, -0.9, 0.9, 16, col, 4, true)
	else:
		b.draw_line(c + Vector2(-8, 16), c + Vector2(-8, -20), col, 5)
		b.draw_line(c + Vector2(14, 10), c + Vector2(14, -26), col, 5)
		b.draw_line(c + Vector2(-8, -20), c + Vector2(14, -26), col, 7)
		b.draw_circle(c + Vector2(-14, 16), 9, col)
		b.draw_circle(c + Vector2(8, 10), 9, col)
	if not on:
		b.draw_line(c + Vector2(-30, -30), c + Vector2(30, 30), Color(1, 0.4, 0.5, 0.9), 5)
