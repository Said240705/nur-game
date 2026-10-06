extends Node
## Developer tool: drives chapter one without a player and saves screenshots.
## Only loaded when the game is started with user arguments, e.g.
##   godot --path . -- --shots=/tmp/shots --mode=village
## Modes: intro, village, walkable, story.

var _main: Node
var _dir := "user://shots"
var _mode := "village"


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
	var v: Node2D = _main.village
	match _mode:
		"intro":
			_main._intro()
			for i in 10:
				await _wait(3.0)
				await _shot("intro_%d" % i)
				_tap()
		"village":
			_free_roam()
			await _wait(1.0)
			await _shot("v_start")
			await _walk(Vector2(1, 0.6), 2.5)
			await _shot("v_walk")
			v.nur.position = Vector2(1000, 600)
			await _wait(1.0)
			await _shot("v_mother")
		"walkable":
			_free_roam()
			v.camera.zoom = Vector2(1.25, 1.25)
			v.nur.position = Vector2(768, 520)
			v.camera.limit_right = 100000
			v.queue_redraw()
			v.draw.connect(func() -> void:
				for poly in v.WALKABLE:
					v.draw_colored_polygon(PackedVector2Array(poly), Color(0, 1, 0, 0.25))
				for r in v.BLOCKED_RECTS:
					v.draw_rect(r, Color(1, 0, 0, 0.35))
				for c in v.BLOCKED_CIRCLES:
					v.draw_circle(c[0], c[1], Color(1, 0, 0, 0.35)))
			await _wait(1.5)
			await _shot("walkable")
		"story":
			_free_roam()
			v.nur.position = Vector2(560, 470)
			await _wait(0.5)
			_main._on_talk()
			v.nur.position = Vector2(780, 260)
			await _wait(0.5)
			_main._busy = false
			v.nur.position = Vector2(790, 225)
			_main._on_talk()
			await _wait(2.0)
			await _shot("s_zara")
			for i in 14:
				_tap()
				await _wait(0.3)
			await _wait(1.0)
			v.nur.position = Vector2(860, 612)
			await _wait(1.0)
			await _shot("s_eli_1")
			for i in 3:
				_tap()
				await _wait(1.2)
			await _shot("s_eli_2")
			for i in 12:
				_tap()
				await _wait(1.0)
			await _wait(3.0)
			await _shot("s_silence")
			v.nur.position = Vector2(985, 625)
			await _wait(1.0)
			await _shot("s_toy")
			for i in 10:
				_tap()
				await _wait(0.5)
			await _wait(1.0)
			v.nur.position = Vector2(730, 712)
			await _wait(5.0)
			await _shot("s_memory")
			_tap()
			await _wait(3.5)
			await _shot("s_face")
			for i in 4:
				_tap()
				await _wait(0.6)
			await _wait(3.0)
			await _shot("s_freed")
	get_tree().quit()


func _free_roam() -> void:
	_main.beat = _main.Beat.FIND_ELI
	_main.cinema.set_black(0.0)
	_main._resume()


func _walk(dir: Vector2, seconds: float) -> void:
	_main.village.nur.move_input = dir
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		_main.village.nur.move_input = dir
	_main.village.nur.move_input = Vector2.ZERO


func _tap() -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = Vector2(960, 300)
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
