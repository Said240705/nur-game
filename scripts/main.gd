extends Node
## The director: intro -> title -> the valley -> memories -> end of the prologue.
## Owns every pause and every camera move, so gameplay code never knows about cutscenes.

const Texts := preload("res://scripts/texts.gd")
const World := preload("res://scripts/world/world.gd")
const Game := preload("res://scripts/game/game.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Cinema := preload("res://scripts/ui/cinema.gd")
const UpgradePanel := preload("res://scripts/ui/upgrade_panel.gd")

## Where the camera looks when it frames the White Peak above the village.
const PEAK_LOOK := Vector3(160, 140, -640)

var world: Node3D
var game: Node3D
var hud: CanvasLayer
var cinema: CanvasLayer
var upgrades: CanvasLayer
var memories := 0

var _first_run := true


func _ready() -> void:
	world = World.new()
	add_child(world)

	hud = Hud.new()
	hud.visible = false
	add_child(hud)
	upgrades = UpgradePanel.new()
	upgrades.chosen.connect(_on_upgrade_chosen)
	add_child(upgrades)
	cinema = Cinema.new()
	add_child(cinema)

	var dev := OS.get_cmdline_user_args()
	if dev.size() > 0:
		var tool: Node = load("res://scripts/dev/autoshot.gd").new()
		tool.setup(self, dev)
		add_child(tool)
		return
	_intro()


func _intro() -> void:
	cinema.set_black(1.0)
	world.shot(Vector3(0, 40, 90), Vector3(0, 0, 0))
	await cinema.wait(1.2)
	for line in Texts.INTRO_LINES:
		await cinema.caption(line, 2.4)
	await cinema.wait(0.4)
	# A slow crane down over the sleeping village, ending under the White Peak.
	world.dolly(Vector3(0, 42, 95), Vector3(-2, 3.4, 31), Vector3(0, 0, 0), PEAK_LOOK, 16.0)
	await cinema.fade_to(0.25, 3.0)
	await cinema.caption(Texts.ELI_LEAD, 2.6, 38)
	await cinema.caption(Texts.ELI_LINE, 3.0, 58)
	await title(false)


func title(reframe := true) -> void:
	hud.visible = false
	if reframe:
		world.dolly(Vector3(2, 3.6, 36), Vector3(-2, 3.4, 31), PEAK_LOOK + Vector3(-60, 0, 0), PEAK_LOOK, 12.0)
	cinema.fade_to(0.0, 2.0)
	Sfx.play("bell", -4.0)
	await cinema.show_title(Texts.TITLE, Texts.SUBTITLE)
	await cinema.prompt_and_wait(Texts.TAP_TO_START)
	cinema.hide_title(1.2)
	start_game(2.8)
	if _first_run:
		_first_run = false
		await cinema.wait(2.0)
		await cinema.hint(Texts.HINT_MOVE, 3.5)
		await cinema.hint(Texts.HINT_LIGHT, 3.5)


func start_game(camera_blend := 0.0) -> void:
	if game:
		game.queue_free()
	memories = 0
	game = Game.new()
	game.world = world
	game.joystick = hud
	game.level_up.connect(_on_level_up)
	game.light_out.connect(_on_light_out)
	game.stats_changed.connect(hud.update_stats)
	world.add_child(game)
	world.follow(game.nur, camera_blend)
	hud.set_memories(0)
	hud.reset_touch()
	hud.visible = true
	get_tree().paused = false


func _on_level_up(level: int) -> void:
	get_tree().paused = true
	hud.reset_touch()
	var index := Texts.MEMORY_LEVELS.find(level)
	if index >= 0:
		await _memory(index)
		if index == Texts.MEMORIES.size() - 1:
			await _prologue_end()
			return
	upgrades.open(game.roll_upgrades(3))


func _memory(index: int) -> void:
	Sfx.play("bell", -8.0, 1.5)
	hud.visible = false
	cinema.fade_to(0.55, 0.9)
	await cinema.letterbox(true)
	await cinema.card("%s · %s" % [Texts.MEMORY_HEADER, Texts.ROMAN[index]], Texts.MEMORIES[index], Texts.TAP_TO_CONTINUE)
	memories = index + 1
	hud.set_memories(memories)
	cinema.fade_to(0.0, 0.6)
	await cinema.letterbox(false, 0.6)
	hud.visible = true


func _on_upgrade_chosen(id: String) -> void:
	game.apply_upgrade(id)
	hud.reset_touch()
	get_tree().paused = false


func _on_light_out() -> void:
	hud.visible = false
	await cinema.wait(2.0)
	await cinema.fade_to(0.7, 1.5)
	await cinema.card("", Texts.LIGHT_OUT, Texts.LIGHT_OUT_SUB)
	await cinema.fade_to(1.0, 0.8)
	start_game()
	await cinema.fade_to(0.0, 1.2)


func _prologue_end() -> void:
	hud.visible = false
	await cinema.fade_to(1.0, 2.5)
	game.queue_free()
	game = null
	await cinema.letterbox(false, 0.1)
	for line in Texts.ENDING:
		await cinema.caption(line, 3.0, 40)
	Sfx.play("bell", -6.0, 0.9)
	await cinema.caption(Texts.PROLOGUE_END, 2.5, 56)
	await cinema.caption(Texts.TO_BE_CONTINUED, 2.5, 34)
	get_tree().paused = false
	await title()
