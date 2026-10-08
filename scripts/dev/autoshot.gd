extends Node
## Developer tool: plays a little by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=jobs|contract
## Starts from a fresh life and never touches the real save.

const Contract := preload("res://scripts/game/contract.gd")

var _main: Node
var _dir := "user://shots"
var _mode := "jobs"


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
		"jobs":
			# One screenshot per job: set the capital to each status in turn.
			for r in [0, 1, 2, 3, 5, 7]:
				s.cash = _main.Data.RANKS[r]["worth"] + 10.0
				_main._rebuild_pages()
				await _wait(1.6)
				var game := _game()
				if game:
					for i in 3:
						game.tap(game.size * Vector2(0.5, 0.6))
						await _wait(0.3)
				await _wait(0.4)
				await _shot("job_%d" % r)
		"contract":
			s.cash = 5000.0
			var c := Contract.make("wash", 4000.0, true)
			while not Contract.is_bad(c):
				c = Contract.make("wash", 4000.0, true)
			_main._show_contract(c)
			await _wait(1.2)
			await _shot("contract")
			_main._sign(c)
			await _wait(1.0)
			await _shot("contract_signed")
	get_tree().quit()


func _game() -> Control:
	for n in _main._pages["work"].find_children("*", "Control", true, false):
		if n.has_signal("earned"):
			return n
	return null


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	print("shot: ", label)
