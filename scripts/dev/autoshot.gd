extends Node
## Developer tool: plays a little by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=city|work|cars|away|contract
## Starts from a fresh life and never touches the real save.

const Contract := preload("res://scripts/game/contract.gd")
const Cars := preload("res://scripts/game/cars.gd")

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
		"work":
			_main._show_tab("work")
			await _wait(1.0)
			await _shot("work_ready")
			_main._start_shift()
			for i in 6:
				_main._game.tap(_main._game.size * Vector2(0.5, 0.65))
				await _wait(0.4)
			await _shot("work_shift")
			_main._shift_left = 0.05
			await _wait(0.6)
			await _shot("work_done")
			s.energy = 10.0
			_main._shift_done = false
			_main._refresh_work()
			await _wait(0.4)
			await _shot("work_tired")
		"cars":
			s.cash = 20000.0
			_main._show_tab("prop")
			await _wait(1.0)
			_main._venue_page = null
			var scroll: ScrollContainer = _main._pages["prop"].get_child(0)
			scroll.scroll_vertical = 1200
			await _wait(0.6)
			await _shot("garage")
			_main._show_market("car")
			await _wait(0.8)
			await _shot("market")
			var car: Dictionary = Cars.make("car", false)
			car["issue"] = "mileage"
			_main._show_car(car)
			await _wait(0.9)
			await _shot("car")
			_main._check_car(car, false)
			await _wait(0.9)
			await _shot("car_checked")
			var bad: Dictionary = Cars.make("oldcar", false)
			bad["issue"] = "pledge"
			_main._show_car(bad)
			await _wait(0.8)
			_main._buy_car(bad, bad["price"])
			await _wait(0.9)
			await _shot("car_pledge")
			_main._close_modal()
			var good: Dictionary = Cars.make("oldcar", false)
			good["issue"] = ""
			s.buy_vehicle(good, 100.0)
			s.pending_break = "oldcar"
			_main._show_breakdown()
			await _wait(0.9)
			await _shot("breakdown")
		"away":
			s.cash = 5e6
			var a: Dictionary = s.open_venue("shawarma", 8, 30000.0)
			s.hire(a, "cook", 3)
			s.hire(a, "clean", 1)
			s.hire(a, "manager", 1)
			s.buy_stock(a, 7)
			var b: Dictionary = s.open_venue("coffee", 13, 1.8e6)
			s.hire(b, "barista", 2)
			s.buy_stock(b, 3)
			var c: Dictionary = s.open_venue("wash", 5, 3e5)
			s.hire(c, "washer", 2)
			s.buy_stock(c, 2)
			s.energy = 20.0
			for i in 2:
				s.next_day()
			_main._rebuild_pages()
			_main._show_tab("biz")
			await _wait(0.8)
			await _shot("biz_totals")
			_main._welcome_back(26.0 * 3600.0)
			await _wait(1.0)
			await _shot("away")
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
