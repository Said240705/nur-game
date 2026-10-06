extends Node
## The director of chapter one: intro, title, then the story beats in the village.
## Owns every pause, so the village and its actors never know about cutscenes.

const Texts := preload("res://scripts/texts.gd")
const Village := preload("res://scripts/village/village.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Cinema := preload("res://scripts/ui/cinema.gd")
const Dialogue := preload("res://scripts/ui/dialogue.gd")

enum Beat { INTRO, FIND_ELI, SILENCE, FREED }

var village: Node2D
var hud: CanvasLayer
var cinema: CanvasLayer
var dialogue: CanvasLayer
var beat := Beat.INTRO

var _busy := true
var _talked := {}
var _has_toy := false
var _asked_for_toy := false


func _ready() -> void:
	village = Village.new()
	add_child(village)
	hud = Hud.new()
	hud.visible = false
	hud.talk_pressed.connect(_on_talk)
	add_child(hud)
	dialogue = Dialogue.new()
	add_child(dialogue)
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
	get_tree().paused = true
	cinema.set_black(1.0)
	await cinema.wait(1.2)
	for line in Texts.INTRO_LINES:
		await cinema.caption(line, 2.4)
	await cinema.letterbox(true, 0.1)
	cinema.fade_to(0.15, 3.0)
	Sfx.play("bell", -4.0)
	await cinema.show_title(Texts.TITLE, Texts.SUBTITLE)
	await cinema.prompt_and_wait(Texts.TAP_TO_START)
	await cinema.hide_title(1.2)
	await cinema.fade_to(0.6, 0.8)
	await cinema.caption("%s\n%s" % [Texts.CHAPTER, Texts.CHAPTER_NAME], 2.6, 50)
	cinema.fade_to(0.0, 1.5)
	await cinema.letterbox(false, 1.5)
	await talk(Texts.OPENING)
	beat = Beat.FIND_ELI
	_resume()
	await cinema.hint(Texts.HINT_MOVE, 3.5)
	await cinema.hint(Texts.HINT_GOAL, 4.0)


## Run a conversation with the world paused.
func talk(lines: Array) -> void:
	_busy = true
	get_tree().paused = true
	hud.show_talk(false)
	hud.reset_touch()
	await dialogue.play(lines)


func _resume() -> void:
	hud.visible = true
	hud.reset_touch()
	get_tree().paused = false
	_busy = false


func _process(_delta: float) -> void:
	if _busy:
		return
	var who: String = village.nearby_person()
	hud.show_talk(who != "" and not (who == "eli" and beat == Beat.FIND_ELI))
	var nur_at: Vector2 = village.nur.position

	match beat:
		Beat.FIND_ELI:
			if who == "eli":
				_eli_scene()
		Beat.SILENCE:
			if not _has_toy and nur_at.distance_to(village.keepsake.position) < 34.0:
				_find_toy()
			elif village.faceless and nur_at.distance_to(village.faceless.position) < 75.0:
				if _has_toy:
					_free_arsen()
				elif not _asked_for_toy:
					_asked_for_toy = true
					_say(Texts.NEED_TOY)


func _on_talk() -> void:
	if _busy:
		return
	var who: String = village.nearby_person()
	village.nur.face(village.PEOPLE.get(who, village.nur.position))
	match who:
		"zara":
			_say(Texts.ZARA_TALK)
		"traveler":
			_say(Texts.TRAVELER_TALK)
		"mother":
			_say(Texts.MOTHER_TALK)
		"eli":
			_say([[Texts.ELI, "Тётя, мне нельзя говорить с чужими.", ""]])


func _say(lines: Array) -> void:
	await talk(lines)
	_resume()


func _eli_scene() -> void:
	_busy = true
	village.nur.face(village.PEOPLE["eli"])
	hud.visible = false
	await cinema.letterbox(true, 0.8)
	await talk(Texts.ELI_SCENE)
	Sfx.wind_level = 1.0
	await village.set_silence(1.0, 4.0)
	village.summon_faceless()
	await talk(Texts.SILENCE_COMES)
	await cinema.letterbox(false, 0.8)
	beat = Beat.SILENCE
	_resume()
	cinema.hint(Texts.HINT_FACELESS, 4.5)


func _find_toy() -> void:
	_has_toy = true
	village.keepsake.taken = true
	Sfx.play("shard", -6.0)
	await talk(Texts.FOUND_TOY)
	_resume()


func _free_arsen() -> void:
	_busy = true
	beat = Beat.FREED
	village.nur.face(village.faceless.position)
	hud.visible = false
	get_tree().paused = true
	Sfx.play("bell", -8.0, 1.5)
	cinema.fade_to(0.55, 0.9)
	await cinema.letterbox(true)
	await cinema.card(Texts.MEMORY_HEADER, Texts.ARSEN_MEMORY, Texts.TAP_TO_CONTINUE)
	cinema.fade_to(0.0, 0.8)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(village.faceless, "remembered", 1.0, 2.0)
	await tw.finished
	await dialogue.play(Texts.ARSEN_FREED.slice(0, 2))
	tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(village.faceless, "faded", 1.0, 2.5)
	tw.parallel().tween_property(village.faceless, "position:y", village.faceless.position.y - 40.0, 2.5)
	Sfx.play("fade", -8.0, 0.8)
	await tw.finished
	Sfx.wind_level = 0.6
	village.set_silence(0.35, 3.0)
	await dialogue.play(Texts.ARSEN_FREED.slice(2))
	await cinema.fade_to(1.0, 2.5)
	Sfx.play("bell", -6.0, 0.9)
	await cinema.caption(Texts.DEMO_END, 2.5, 52)
	await cinema.caption(Texts.TO_BE_CONTINUED, 2.5, 34)
