extends Node
## Developer tool: drives the prologue without a player and saves screenshots.
## Only loaded when the game is started with user arguments, e.g.
##   godot --path . -- --shots=/tmp/shots --mode=lev
## Modes: intro, note, lev, mira.

var _main: Node
var _dir := "user://shots"
var _mode := "lev"


func setup(main: Node, args: PackedStringArray) -> void:
	_main = main
	for a in args:
		if a.begins_with("--shots="):
			_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(_dir)
	_run()


func _run() -> void:
	match _mode:
		"intro":
			_main._intro()
			for i in 14:
				await _wait(3.0)
				await _shot("intro_%02d" % i)
				if i in [5, 6, 7]:
					_tap()
		"note":
			_main.cinema.set_black(0.0)
			_main.lev_phone.visible = true
			_main.overlay.note(_main.Texts.NOTE_TEXT)
			await _wait(2.0)
			await _shot("note")
		"lev":
			_main.cinema.set_black(1.0)
			await _main._start_lev_phone()
			await _wait(1.5)
			await _shot("lev_lock")
			var p: Control = _main.lev_phone
			p._on_lock_tapped()
			await _wait(1.0)
			await _shot("lev_home")
			p.open_app("messages")
			await _wait(1.0)
			await _shot("app_chats")
			p._stack.back()._open_chat(p.chats[0])
			await _wait(1.5)
			await _shot("app_chat_vera")
			p.pop()
			p.pop()
			await _wait(0.4)
			p.open_app("notes")
			await _wait(1.0)
			await _shot("app_notes")
			p._stack.back()._open(p.data.NOTES[0])
			await _wait(1.0)
			await _shot("app_note")
			p.pop()
			p.pop()
			await _wait(0.4)
			p.open_app("browser")
			await _wait(1.0)
			await _shot("app_site")
			var br: Control = p._stack.back()
			(br.get_meta("scroll") as ScrollContainer).scroll_vertical = 1100
			await _wait(0.6)
			await _shot("app_site_2")
			br._open_article(p.data.SITE["articles"][0])
			await _wait(1.0)
			await _shot("app_article")
			var art: Control = p._stack.back()
			var sc: ScrollContainer = art.get_meta("scroll")
			sc.scroll_vertical = 2200
			await _wait(0.6)
			await _shot("app_article_2")
			sc.scroll_vertical = 100000
			await _wait(0.6)
			await _shot("app_article_3")
			p.pop()
			p.pop()
			await _wait(0.4)
			p.open_app("photos")
			await _wait(1.0)
			await _shot("app_photos")
			var g: Control = p._stack.back()
			g._show_tab("Альбомы")
			await _wait(0.8)
			await _shot("app_albums")
			g._open(p.data.PHOTOS[1])
			await _wait(1.0)
			await _shot("app_photo")
			p.pop()
			p.pop()
			await _wait(0.4)
			p.open_app("voicemail")
			await _wait(1.0)
			await _shot("app_voice")
			p._stack.back()._open(p.data.VOICEMAIL[0])
			await _wait(4.0)
			await _shot("app_voice_msg")
		"mira":
			_main.cinema.set_black(1.0)
			_main.lev_phone.visible = true
			_main._on_door()
			for i in 60:
				await _wait(1.5)
				if i < 12:
					await _shot("door_%02d" % i)
				if _main.mira_phone:
					break
				if i % 2 == 1:
					_tap()
			await _wait(3.0)
			await _shot("mira_lock")
			var m: Control = _main.mira_phone
			m._on_lock_tapped()
			await _wait(0.8)
			for k in ["1", "2", "3", "4"]:
				m._on_key(k)
				await _wait(0.1)
			await _wait(0.2)
			await _shot("mira_wrong")
			await _wait(1.0)
			for k in ["0", "3"]:
				m._on_key(k)
			await _wait(0.3)
			await _shot("mira_keypad")
			for k in ["1", "2"]:
				m._on_key(k)
			await _wait(2.0)
			await _shot("mira_unlocked")
			await _wait(5.0)
			await _shot("mira_chapter")
	get_tree().quit()


func _tap() -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = Vector2(get_window().size) * 0.5
	Input.parse_input_event(e)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = e.position
	Input.parse_input_event(up)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [_dir, label])
		print("shot: ", label)
