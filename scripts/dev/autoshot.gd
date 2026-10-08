extends Node
## Developer tool: plays the first minutes by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=start|grow|deep
## Uses a fresh mine, so it never touches a real save.

const Mine := preload("res://scripts/game/mine.gd")

var _main: Node
var _dir := "user://shots"
var _mode := "start"


func setup(main: Node, args: PackedStringArray) -> void:
	_main = main
	for a in args:
		if a.begins_with("--shots="):
			_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var m: RefCounted = Mine.new()
	_use(m)
	match _mode:
		"start":
			await _wait(1.0)
			await _shot("start")
			m.tap("shaft:0")
			await _wait(2.0)
			await _shot("digging")
			await _wait(2.5)
			m.tap("lift")
			await _wait(1.6)
			await _shot("lift")
			await _wait(1.5)
			m.tap("cart")
			await _wait(2.8)
			await _shot("sold")
		"grow":
			m.coins = 5000.0
			m.upgrade("shaft:0", 10)
			m.hire("shaft:0")
			m.hire("lift")
			m.hire("cart")
			m.open_shaft()
			m.hire("shaft:1")
			await _wait(6.0)
			await _shot("grow")
			_main._open_sheet("shaft:1")
			await _wait(1.0)
			await _shot("sheet")
		"deep":
			m.coins = 1e14
			for i in 9:
				m.open_shaft()
			for i in m.shafts.size():
				m.upgrade("shaft:%d" % i, 30)
				m.hire("shaft:%d" % i)
			m.hire("lift")
			m.hire("cart")
			m.upgrade("lift", 60)
			await _wait(4.0)
			_main.world.scroll = 1400.0
			await _wait(1.0)
			await _shot("deep")
			_main.world.scroll = _main.world.max_scroll()
			await _wait(1.0)
			await _shot("bottom")
			_main._welcome_back(3600.0)
			await _wait(1.0)
			await _shot("away")
	get_tree().quit()


func _use(m: RefCounted) -> void:
	_main.mine = m
	_main.world.mine = m
	_main.sheet.mine = m
	_main._shown = 0.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	print("shot: ", label)
