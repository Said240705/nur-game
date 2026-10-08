extends Node
## Developer tool: plays a little by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=city|jobs|contract
## Starts from a fresh life and never touches the real save.

const Contract := preload("res://scripts/game/contract.gd")

var _main: Node
var _dir := "user://shots"
var _mode := "city"


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
	_main._event_t = 9999.0
	_main._deal_t = 9999.0
	_main._rank_seen = 99
	match _mode:
		"city":
			s.cash = 60000.0
			var v1: Dictionary = s.open_venue("shawarma", 8, 300.0)
			s.hire(v1, "cook", 2)
			s.hire(v1, "clean", 1)
			s.buy_stock(v1, 7)
			var v2: Dictionary = s.open_venue("coffee", 13, 18000.0)
			s.hire(v2, "barista", 2)
			s.hire(v2, "waiter", 1)
			s.buy_stock(v2, 3)
			s.renovate(v2)
			s.open_venue("wash", 5, 3000.0)
			for i in 3:
				s.next_day()
			_main._rebuild_pages()
			_main._show_tab("city")
			await _wait(1.2)
			await _shot("city")
			_main._on_plot(14)
			await _wait(1.0)
			await _shot("plot")
			_main._close_modal()
			_main._show_tab("biz")
			await _wait(0.8)
			await _shot("venues")
			_main._open_venue(v1)
			await _wait(1.0)
			await _shot("venue_top")
			_main._venue_page._scroll.scroll_vertical = 1300
			await _wait(0.8)
			await _shot("venue_mid")
			_main._venue_page._scroll.scroll_vertical = 2600
			await _wait(0.8)
			await _shot("venue_low")
		"contract":
			s.cash = 5000.0
			var c := Contract.make("wash", 3000.0, true, 5)
			while not Contract.is_bad(c):
				c = Contract.make("wash", 3000.0, true, 5)
			_main._show_contract(c)
			await _wait(1.2)
			await _shot("contract")
			_main._sign(c)
			await _wait(1.0)
			await _shot("contract_signed")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	print("shot: ", label)
