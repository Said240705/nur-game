extends Node
## Developer tool: drives the game without a player and saves screenshots.
## Only loaded when the game is started with user arguments, e.g.
##   godot --path . -- --shots=/tmp/shots --mode=game
## Modes: intro, game, upgrade, memory, survive (headless soak test).

var _main: Node
var _dir := "user://shots"
var _mode := "game"
var _t := 0.0


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


func _process(delta: float) -> void:
	_t += delta


## Stands in for the touch joystick: Nur walks in slow circles.
func get_vector() -> Vector2:
	return Vector2.from_angle(_t * 0.5) * 0.25


func _run() -> void:
	match _mode:
		"intro":
			_main._intro()
			for i in 8:
				await _wait(3.5)
				await _shot("intro_%d" % i)
		"game":
			_start()
			await _wait(4.0)
			await _shot("game_start")
			await _wait(20.0)
			await _shot("game_20s")
		"upgrade":
			_start()
			await _wait(3.0)
			_main._on_level_up(3)
			await _wait(1.5)
			await _shot("upgrade")
		"memory":
			_start()
			await _wait(3.0)
			_main._on_level_up(10)
			await _wait(5.0)
			await _shot("memory")
		"probe":
			_start()
			var g: Node2D = _main.game
			var pulses := [0]
			g.nur.pulsed.connect(func(_o, _r, _d): pulses[0] += 1)
			await _wait(25.0)
			var near := 0
			var dmin := 99999.0
			for e in g.get_child(4).get_children():
				dmin = minf(dmin, e.global_position.distance_to(g.nur.global_position))
			print("pulses=%d enemies=%d nearest=%d motes=%d xp=%d light=%d" % [pulses[0], g.get_child(4).get_child_count(), dmin, g.get_child(3).get_child_count(), g.xp, g.nur.light])
		"survive":
			_start()
			_main.game.nur.max_light = 100000.0
			_main.game.nur.light = 100000.0
			for i in 6:
				await _wait(30.0)
				print("t=%ds enemies=%d level=%d fps=%d" % [(i + 1) * 30, _main.game.get_child(4).get_child_count(), _main.game.level, Engine.get_frames_per_second()])
				if get_tree().paused:
					_main.upgrades._pick(_main.game.roll_upgrades(1)[0])
	get_tree().quit()


func _start() -> void:
	_main.cinema.set_black(0.0)
	_main.start_game()
	_main.game.joystick = self


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [_dir, label])
		print("shot: ", label)
