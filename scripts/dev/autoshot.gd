extends Node
## Developer tool: plays by itself and saves screenshots.
##   godot --path . -- --shots=DIR --mode=title|play|over

const Shapes := preload("res://scripts/game/shapes.gd")

var _main: Node
var _dir := "user://shots"
var _mode := "play"


func setup(main: Node, args: PackedStringArray) -> void:
	_main = main
	for a in args:
		if a.begins_with("--shots="):
			_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	var game: Node = _main.game
	match _mode:
		"title":
			_main._title(false)
			await _wait(1.5)
			await _shot("title")
		"play":
			game.new_round()
			game.paused = false
			await _wait(1.0)
			await _shot("play_0")
			# Drag the first piece by hand to show the ghost.
			var p: Dictionary = game.pieces[0]
			game._drag = 0
			game._move(game.view.position + game.view.cell_center(Vector2i(3, 3)) + Vector2(0, game.LIFT))
			await _wait(0.6)
			await _shot("play_drag")
			game._drag = -1
			game.view.hide_ghost()
			for move in 40:
				if game.over:
					break
				_auto_move(game)
				await _wait(0.12)
				if move in [6, 14, 22]:
					await _wait(0.15)
					await _shot("play_%02d" % move)
			await _wait(0.5)
			await _shot("play_end")
		"over":
			game.new_round()
			for i in 64:
				game.board.cells[i] = (i % 7) + 1 if i % 5 != 0 else 0
			game.paused = false
			game._check_over()
			await _wait(3.5)
			await _shot("over")
	get_tree().quit()


## Places some piece where it clears the most lines, as a greedy player would.
func _auto_move(game: Node) -> void:
	var best := -1
	var best_at := Vector2i.ZERO
	var best_i := -1
	for i in 3:
		var p: Dictionary = game.pieces[i]
		if p["placed"]:
			continue
		var shape := Shapes.cells(p["shape"])
		for y in 8:
			for x in 8:
				var at := Vector2i(x, y)
				if game.board.can_place(shape, at):
					var l: Dictionary = game.board.lines_if_placed(shape, at)
					var v: int = (l["rows"].size() + l["cols"].size()) * 100 + y * 3 + x
					if v > best:
						best = v
						best_at = at
						best_i = i
	if best_i >= 0:
		game._place(best_i, best_at)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, label])
	print("shot: ", label)
