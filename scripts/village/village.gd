extends Node2D
## Chapter one: the village at the foot of the White Peak, built on the painted
## concept art. World units are pixels of the original 1536x1024 painting.

const Fx := preload("res://scripts/fx.gd")
const Nur := preload("res://scripts/actors/nur.gd")
const Faceless := preload("res://scripts/actors/faceless.gd")
const Keepsake := preload("res://scripts/actors/keepsake.gd")
const Tracks := preload("res://scripts/actors/tracks.gd")
const PAINTING := preload("res://assets/art/village_2x.jpg")
const FOG := preload("res://shaders/fog.gdshader")

const SIZE := Vector2(1536, 1024)
const ZOOM := 2.0
const TALK_RADIUS := 80.0
const START := Vector2(500, 318)

## Where people stand in the painting; the talk spot is their feet.
const PEOPLE := {
	"zara": Vector2(790, 196),
	"traveler": Vector2(556, 372),
	"mother": Vector2(1092, 598),
	"eli": Vector2(852, 566),
}
const KEEPSAKE_AT := Vector2(992, 628)
const FACELESS_FROM := Vector2(716, 990)
const FACELESS_TO := Vector2(712, 770)

## Snowy ground you can walk on, traced over the painting.
const WALKABLE := [
	[Vector2(462, 292), Vector2(520, 282), Vector2(585, 300), Vector2(612, 338), Vector2(650, 378),
	Vector2(720, 388), Vector2(870, 388), Vector2(950, 398), Vector2(1005, 396), Vector2(1030, 410),
	Vector2(1020, 440), Vector2(1030, 480), Vector2(1065, 515), Vector2(1110, 545), Vector2(1170, 575),
	Vector2(1235, 600), Vector2(1240, 625), Vector2(1180, 640), Vector2(1080, 655), Vector2(1010, 650),
	Vector2(950, 665), Vector2(905, 690), Vector2(860, 740), Vector2(800, 800), Vector2(790, 880),
	Vector2(780, 1010), Vector2(650, 1010), Vector2(660, 900), Vector2(640, 800), Vector2(625, 760),
	Vector2(600, 700), Vector2(580, 640), Vector2(600, 560), Vector2(605, 500), Vector2(585, 470),
	Vector2(540, 440), Vector2(490, 400), Vector2(450, 360), Vector2(440, 325)],
	[Vector2(1000, 398), Vector2(1078, 398), Vector2(1072, 282), Vector2(1012, 282)],
	[Vector2(705, 200), Vector2(1000, 205), Vector2(1060, 240), Vector2(1072, 285),
	Vector2(1012, 285), Vector2(985, 245), Vector2(705, 245)],
]
## The well and the people painted into the scene.
const BLOCKED_RECTS := [Rect2(640, 392, 232, 211), Rect2(868, 525, 72, 78)]
const BLOCKED_CIRCLES := [[Vector2(1092, 598), 26.0], [Vector2(556, 386), 22.0], [Vector2(790, 196), 22.0]]
const LANTERNS := [
	Vector2(505, 250), Vector2(1040, 378), Vector2(836, 462), Vector2(705, 486),
	Vector2(605, 642), Vector2(1180, 473), Vector2(178, 826), Vector2(808, 112),
]

var nur: Node2D
var camera: Camera2D
var faceless: Node2D
var keepsake: Node2D

var _dark: CanvasModulate
var _lamps: Array[PointLight2D] = []
var _fog_mat: ShaderMaterial
var _silence := 0.0
var _t := 0.0
var _polys: Array[PackedVector2Array] = []


func _ready() -> void:
	# The village keeps breathing (snow, fog, lanterns) during dialogue pauses;
	# only Nur stops.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in WALKABLE:
		_polys.append(PackedVector2Array(p))

	var bg := Sprite2D.new()
	bg.texture = PAINTING
	bg.centered = false
	bg.scale = SIZE / PAINTING.get_size()
	add_child(bg)

	_dark = CanvasModulate.new()
	_dark.color = Color(0.8, 0.82, 0.92)
	add_child(_dark)

	var lamp_tex := Fx.radial_texture(256)
	for p in LANTERNS:
		var l := PointLight2D.new()
		l.texture = lamp_tex
		l.color = Color(1.0, 0.7, 0.4)
		l.energy = 0.55
		l.texture_scale = 0.9
		l.position = p
		add_child(l)
		_lamps.append(l)

	var tracks := Tracks.new()
	add_child(tracks)

	keepsake = Keepsake.new()
	keepsake.position = KEEPSAKE_AT
	keepsake.visible = false
	add_child(keepsake)

	nur = Nur.new()
	nur.position = START
	nur.tracks = tracks
	nur.can_walk = can_walk
	nur.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(nur)

	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(SIZE.x)
	camera.limit_bottom = int(SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	nur.add_child(camera)
	camera.make_current()

	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 1
	add_child(fog_layer)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG
	_fog_mat.set_shader_parameter("density", 0.0)
	fog.material = _fog_mat
	fog_layer.add_child(fog)

	var snow_layer := CanvasLayer.new()
	snow_layer.layer = 2
	add_child(snow_layer)
	var view := get_viewport().get_visible_rect().size
	snow_layer.add_child(Fx.make_snow(view, 140, 0.8))
	var near := Fx.make_snow(view, 30, 1.6)
	near.scale_amount_min = 1.2
	near.scale_amount_max = 2.2
	near.color = Color(1, 1, 1, 0.55)
	snow_layer.add_child(near)


func can_walk(p: Vector2) -> bool:
	for r: Rect2 in BLOCKED_RECTS:
		if r.has_point(p):
			return false
	for c in BLOCKED_CIRCLES:
		if p.distance_to(c[0]) < c[1]:
			return false
	for poly in _polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


## The person Nur stands close enough to talk to, or "".
func nearby_person() -> String:
	var best := ""
	var best_d := TALK_RADIUS
	for id in PEOPLE:
		var d := nur.position.distance_to(PEOPLE[id])
		if d < best_d:
			best = id
			best_d = d
	return best


## 0 = calm night, 1 = the Silence has fallen: fog, darkness, lanterns out.
func set_silence(amount: float, seconds: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "_silence", amount, seconds)
	await tw.finished


## Bring a Faceless up the stairs from the fog.
func summon_faceless() -> void:
	faceless = Faceless.new()
	faceless.position = FACELESS_FROM
	add_child(faceless)
	move_child(faceless, nur.get_index())
	var tw := create_tween()
	tw.tween_property(faceless, "position", FACELESS_TO, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	keepsake.visible = true


func _process(delta: float) -> void:
	_t += delta
	var center := camera.get_screen_center_position()
	_fog_mat.set_shader_parameter("cam_pos", center * ZOOM)
	_fog_mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	_fog_mat.set_shader_parameter("density", _silence * 0.85)
	_fog_mat.set_shader_parameter("clear_radius", 0.34 - _silence * 0.12)
	_dark.color = Color(0.8, 0.82, 0.92).lerp(Color(0.5, 0.56, 0.78), _silence)
	for i in _lamps.size():
		# Lanterns flicker; as the Silence falls they go out one after another.
		var out := clampf(_silence * 1.6 - float(i) / _lamps.size(), 0.0, 1.0)
		var flicker := 0.9 + 0.1 * sin(_t * 9.0 + i * 1.7) * sin(_t * 3.3 + i)
		_lamps[i].energy = 0.55 * flicker * (1.0 - out)
