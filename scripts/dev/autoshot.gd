extends Node
## Developer tool: plays a little by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=tour
## Starts from a fresh life and never touches the real save.

var _main: Node
var _dir := "user://shots"
var _mode := "tour"


func setup(main: Node, args: PackedStringArray) -> void:
	_main = main
	for a in args:
		if a.begins_with("--shots="):
			_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var s: RefCounted = _main.s
	_main._event_t = 999.0
	_main._deal_t = 999.0
	await _wait(1.0)
	await _shot("work")
	for i in 5:
		_main._on_work()
		await _wait(0.08)
	await _wait(0.2)
	await _shot("work_tap")
	s.cash = 25000.0
	s.buy_business("shawarma")
	s.upgrade_business("shawarma")
	s.upgrade_business("shawarma")
	s.buy_business("wash")
	s.buy_property("room")
	s.buy_property("bike")
	_main._rank_seen = 99
	_main._rebuild_pages()
	_main._show_tab("biz")
	await _wait(1.0)
	await _shot("biz")
	_main._show_tab("prop")
	await _wait(0.6)
	await _shot("prop")
	_main._show_tab("work")
	_main._deal_t = 0.0
	await _wait(1.0)
	await _shot("deal")
	_main._event_t = 0.0
	await _wait(0.8)
	await _shot("event")
	# Take the first choice.
	for b in _main._modal.find_children("*", "Button", true, false):
		b.pressed.emit()
		break
	await _wait(0.8)
	await _shot("outcome")
	_main._close_modal()
	_main._rank_seen = 2
	s.cash = 2e6
	_main._check_rank()
	await _wait(0.8)
	await _shot("rank")
	_main._close_modal()
	_main._event_t = 999.0
	s.cash = -1e9
	s.debt_days = 6
	await _wait(3.5)
	await _shot("bankrupt")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	print("shot: ", label)
