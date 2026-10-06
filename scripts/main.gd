extends Node
## The director of the prologue: cold open, the rainy city, Lev's own phone as
## the tutorial, the doorbell, the parcel, and Mira's locked phone.

const Texts := preload("res://scripts/texts.gd")
const Phone := preload("res://scripts/phone/phone.gd")
const LevPhone := preload("res://scripts/story/leo_phone.gd")
const MiraPhone := preload("res://scripts/story/mira_phone.gd")
const Cinema := preload("res://scripts/ui/cinema.gd")
const Panels := preload("res://scripts/ui/panels.gd")
const Overlay := preload("res://scripts/ui/overlay.gd")
const Save := preload("res://scripts/save.gd")
const CITY := preload("res://assets/art/lev/city_night.jpg")
const WINDOW := preload("res://assets/art/lev/window.jpg")
const BOARD := preload("res://assets/art/lev/board.jpg")
const PARCEL := preload("res://assets/art/lev/parcel.jpg")

enum Stage { INTRO, LEV_PHONE, PARCEL, MIRA_LOCKED, CHAPTER_ONE, DEDUCTION, CHAPTER_END }

var stage := Stage.INTRO
var lev_phone: Control
var mira_phone: Control
var cinema: CanvasLayer
var panels: CanvasLayer
var overlay: CanvasLayer

var _phones: CanvasLayer
var _seen := {}
var _mira_seen := {}
var _showing_mira := false
var _wrong_codes := 0
## True while restoring a checkpoint: skip lines the player has already heard.
var _resuming := false


func _ready() -> void:
	_phones = CanvasLayer.new()
	add_child(_phones)
	lev_phone = Phone.new()
	lev_phone.setup(LevPhone)
	lev_phone.viewed.connect(_on_viewed)
	lev_phone.visible = false
	_phones.add_child(lev_phone)

	overlay = Overlay.new()
	overlay.door_opened.connect(_on_door)
	overlay.switch_pressed.connect(_switch_phone)
	add_child(overlay)
	panels = Panels.new()
	add_child(panels)
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
	Sfx.rain_level = 0.0
	await cinema.wait(0.8)
	var checkpoint := Save.load_checkpoint()
	if checkpoint != "":
		# The menu sits over the rainy city, below the black of the cinema layer.
		Sfx.music("theme")
		panels.shot(CITY, Vector2(0.6, 0.4), Vector2(0.5, 0.42), 20.0, 1.15, 1.2)
		await cinema.fade_to(0.0, 1.0)
		var i: int = await overlay.choose(Texts.TITLE, Texts.CONTINUE_QUESTION,
			[Texts.CONTINUE % Save.NAMES[checkpoint], Texts.NEW_GAME])
		await cinema.fade_to(1.0, 0.6)
		await panels.hide_frames(0.1)
		if i == 0:
			_resume(checkpoint)
			return
		Save.clear()
	await _cold_open()
	await _title()
	await _city()
	_start_lev_phone()


## A glimpse of the end: a dying phone, a whisper, then back in time.
func _cold_open() -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	cinema.add_child(screen)
	var t := {"a": 0.0}
	screen.draw.connect(func() -> void:
		var c := Vector2(540, 700)
		var a: float = t["a"]
		screen.draw_rect(Rect2(c - Vector2(150, 70), Vector2(270, 140)), Color(0.9, 0.2, 0.2, a), false, 8.0)
		screen.draw_rect(Rect2(c + Vector2(126, -26), Vector2(18, 52)), Color(0.9, 0.2, 0.2, a))
		screen.draw_rect(Rect2(c - Vector2(134, 54), Vector2(14, 108)), Color(0.9, 0.2, 0.2, a))
		var f := screen.get_theme_default_font()
		screen.draw_string(f, c + Vector2(-60, 160), "2%", HORIZONTAL_ALIGNMENT_LEFT, -1, 80, Color(0.9, 0.2, 0.2, a)))
	Sfx.rain_level = 0.9
	Sfx.rain_muffle = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		t["a"] = v
		screen.queue_redraw(), 0.0, 1.0, 1.5)
	await tw.finished
	Sfx.play("buzz", -10.0)
	await cinema.caption(Texts.COLD_OPEN_WHISPER, 2.2, 46)
	tw = create_tween()
	tw.tween_method(func(v: float) -> void:
		t["a"] = v
		screen.queue_redraw(), 1.0, 0.0, 0.15)
	await tw.finished
	screen.queue_free()
	Sfx.rain_level = 0.0
	Sfx.play("whoosh", -6.0, 0.7)
	await cinema.wait(1.2)
	await cinema.caption(Texts.HOURS_BEFORE, 2.0, 56)


func _title() -> void:
	Sfx.rain_level = 0.6
	Sfx.music("theme", 4.0)
	Sfx.rain_muffle = 0.2
	panels.shot(CITY, Vector2(0.95, 0.4), Vector2(0.75, 0.4), 14.0, 1.15, 1.25)
	await cinema.fade_to(0.35, 2.5)
	Sfx.play("bell", -10.0, 0.7)
	await cinema.show_title(Texts.TITLE, Texts.SUBTITLE)
	await cinema.prompt_and_wait(Texts.TAP_TO_START)
	await cinema.hide_title(1.0)
	await cinema.fade_to(0.0, 1.0)


func _city() -> void:
	panels.shot(CITY, Vector2(0.75, 0.42), Vector2(0.3, 0.45), 16.0, 1.25, 1.35)
	for line in Texts.CITY_VOICE:
		await panels.say(line, 2.6)
	# Push in on the one lit window: Lev, awake, staring at his phone.
	await cinema.fade_to(1.0, 0.8)
	panels.shot(WINDOW, Vector2(0.62, 0.5), Vector2(0.66, 0.5), 12.0, 1.0, 1.25)
	await cinema.fade_to(0.0, 1.0)
	await panels.say(Texts.FACE_VOICE[0], 3.0)
	await panels.say(Texts.FACE_VOICE[1], 3.0)
	# Inside: from Lev at his desk across the wall of red string to Vera's photo.
	await cinema.fade_to(1.0, 0.8)
	Sfx.rain_muffle = 0.7
	panels.shot(BOARD, Vector2(0.4, 0.5), Vector2(0.71, 0.3), 9.0, 1.0, 1.2, false)
	await cinema.fade_to(0.0, 1.0)
	await cinema.wait(3.0)
	await panels.say(Texts.FACE_VOICE[2], 3.4)
	await cinema.fade_to(1.0, 1.0)
	await panels.hide_frames(0.1)


## Jump straight to a saved checkpoint.
func _resume(checkpoint: String) -> void:
	_resuming = true
	Sfx.rain_level = 0.45
	Sfx.rain_muffle = 0.75
	match checkpoint:
		"lev_phone":
			_start_lev_phone()
		"mira_locked":
			await _give_mira_phone()
		"chapter_one":
			await _give_mira_phone(false)
			mira_phone._unlock()
	_resuming = false


func _start_lev_phone() -> void:
	stage = Stage.LEV_PHONE
	Save.store("lev_phone")
	Sfx.music("lonely", 4.0)
	lev_phone.visible = true
	Sfx.rain_level = 0.45
	Sfx.rain_muffle = 0.75
	Sfx.play("buzz", -6.0)
	await cinema.fade_to(0.0, 1.2)
	overlay.set_goal(Texts.GOAL_LOOK)
	_nudge()


## If the player wanders without finding what moves the story on, Lev's own
## thoughts point the way, gently and only once each.
func _nudge() -> void:
	await get_tree().create_timer(75.0).timeout
	if stage == Stage.LEV_PHONE and not _seen.has("news:mira"):
		overlay.think(Texts.NUDGE_NEWS, 5.0)
	await get_tree().create_timer(60.0).timeout
	if stage == Stage.LEV_PHONE and not (_seen.has("chat:vera") or _seen.has("note:case_v")):
		overlay.think(Texts.NUDGE_VERA, 5.0)


func _on_viewed(key: String) -> void:
	_seen[key] = true
	if Texts.THOUGHTS.has(key):
		overlay.think(Texts.THOUGHTS[key])
	if stage == Stage.LEV_PHONE and _seen.has("news:mira") and (_seen.has("chat:vera") or _seen.has("note:case_v")):
		stage = Stage.PARCEL
		await get_tree().create_timer(5.0).timeout
		Sfx.play("doorbell", -2.0)
		# The doorbell cuts through: only the rain is left.
		Sfx.music("", 1.5)
		overlay.set_goal("")
		await get_tree().create_timer(0.8).timeout
		overlay.show_door(Texts.OPEN_DOOR)
		overlay.think(Texts.DOORBELL, 3.0)


func _on_door() -> void:
	await cinema.fade_to(1.0, 0.8)
	lev_phone.visible = false
	overlay.set_goal("")
	panels.shot(PARCEL, Vector2(0.52, 0.55), Vector2(0.56, 0.6), 14.0, 1.0, 1.12, false)
	Sfx.rain_muffle = 0.9
	await cinema.fade_to(0.0, 1.2)
	for line in Texts.HALLWAY_VOICE:
		await panels.say(line, 2.8)
	# The note is read over the box itself; the overlay sits above the film frames.
	await overlay.note(Texts.NOTE_TEXT)
	await panels.say(Texts.AFTER_NOTE, 3.2)
	await cinema.fade_to(1.0, 0.8)
	await panels.hide_frames(0.1)
	await _give_mira_phone()


## Mira's phone, locked, in Lev's hands; Lev's own phone one tap away.
func _give_mira_phone(locked := true) -> void:
	if locked:
		Save.store("mira_locked")
	Sfx.music("tension", 5.0)
	lev_phone.visible = false
	mira_phone = Phone.new()
	mira_phone.setup(MiraPhone)
	mira_phone.viewed.connect(_on_mira_viewed)
	mira_phone.unlocked.connect(_on_mira_unlocked)
	_phones.add_child(mira_phone)
	_showing_mira = true
	stage = Stage.MIRA_LOCKED
	Sfx.play("buzz", -8.0)
	await cinema.fade_to(0.0, 1.2)
	if not locked:
		return
	overlay.set_goal(Texts.GOAL_CODE)
	overlay.show_switch(Texts.SWITCH_TO_LEV)
	overlay.think(Texts.MIRA_WALLPAPER, 4.0)


func _switch_phone() -> void:
	Sfx.play("whoosh", -14.0, 1.4)
	_showing_mira = not _showing_mira
	mira_phone.visible = _showing_mira
	lev_phone.visible = not _showing_mira
	overlay.show_switch(Texts.SWITCH_TO_LEV if _showing_mira else Texts.SWITCH_TO_MIRA)


func _on_mira_viewed(key: String) -> void:
	if key.begins_with("wrong_code:"):
		_wrong_codes += 1
		if _wrong_codes % 2 == 1:
			overlay.think(Texts.WRONG_CODE, 4.0)
		return
	_mira_seen[key] = true
	# In the chapter's last scene only «Н.» speaks.
	if Texts.MIRA_THOUGHTS.has(key) and stage != Stage.CHAPTER_END:
		overlay.think(Texts.MIRA_THOUGHTS[key])
	# Once the three people closest to her have been read, Lev draws a conclusion.
	if stage == Stage.CHAPTER_ONE and ["chat:timur", "chat:dasha", "chat:mom"].all(func(k: String) -> bool: return _mira_seen.has(k)):
		stage = Stage.DEDUCTION
		await get_tree().create_timer(5.0).timeout
		_deduce()


func _on_mira_unlocked() -> void:
	stage = Stage.CHAPTER_ONE
	Save.store("chapter_one")
	overlay.set_goal("")
	overlay.show_switch("")
	if not _resuming:
		await overlay.think(Texts.UNLOCKED_VOICE, 3.5)
	await cinema.fade_to(1.0, 1.2)
	Sfx.play("bell", -8.0)
	await cinema.caption("%s\n%s" % [Texts.CHAPTER, Texts.CHAPTER_NAME], 3.0, 64)
	await cinema.fade_to(0.0, 1.0)
	overlay.set_goal(Texts.GOAL_MIRA)
	overlay.show_switch(Texts.SWITCH_TO_LEV)
	await get_tree().create_timer(80.0).timeout
	if stage == Stage.CHAPTER_ONE and not _mira_seen.has("chat:timur"):
		overlay.think(Texts.NUDGE_MIRA, 5.0)


## The first conclusion: who saw Mira last. A wrong answer is argued down by
## the facts in her phone, and Lev thinks again.
func _deduce() -> void:
	await overlay.think(Texts.DEDUCE_READY, 3.0)
	overlay.show_switch("")
	while true:
		var i: int = await overlay.choose(Texts.DEDUCE_HEADER, Texts.DEDUCE_QUESTION, Texts.DEDUCE_OPTIONS)
		if i == Texts.DEDUCE_RIGHT:
			Sfx.play("unlock", -8.0)
			await overlay.think(Texts.DEDUCE_REPLIES[i], 4.5)
			break
		Sfx.play("error", -8.0)
		await overlay.think(Texts.DEDUCE_REPLIES[i], 5.0)
	for line in Texts.DEDUCE_AFTER:
		await overlay.think(line, 4.0)
	_cliffhanger()


## «Н.» notices that Mira's phone is online, and the chapter ends on a threat.
func _cliffhanger() -> void:
	stage = Stage.CHAPTER_END
	if not _showing_mira:
		_switch_phone()
	overlay.show_switch("")
	Sfx.music("dread", 1.0)
	await get_tree().create_timer(1.0).timeout
	mira_phone.open_chat("n")
	await get_tree().create_timer(1.5).timeout
	for line in Texts.N_LIVE:
		mira_phone.set_typing("n", true)
		await get_tree().create_timer(1.6 + line.length() * 0.03).timeout
		mira_phone.set_typing("n", false)
		mira_phone.receive("n", line)
		await get_tree().create_timer(2.4).timeout
	await overlay.think(Texts.N_AFTER, 3.5)
	await cinema.fade_to(1.0, 1.5)
	Sfx.play("bell", -8.0)
	Sfx.music("theme", 3.0)
	await cinema.caption(Texts.CHAPTER_END, 3.0, 64)
	await cinema.caption(Texts.TO_BE_CONTINUED, 3.0, 40)
