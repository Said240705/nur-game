extends Node2D
## One run on the snowfield: Nur, the Faceless, memory motes and the Silence.
## The director (main.gd) listens to the signals and handles every pause.

signal level_up(level: int)
signal light_out
signal stats_changed(light: float, xp: float)

const Texts := preload("res://scripts/texts.gd")
const Fx := preload("res://scripts/fx.gd")
const Nur := preload("res://scripts/game/nur.gd")
const Faceless := preload("res://scripts/game/faceless.gd")
const Mote := preload("res://scripts/game/mote.gd")
const Tracks := preload("res://scripts/game/tracks.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const FOG_SHADER := preload("res://shaders/fog.gdshader")

const MAX_ENEMIES := 150
const MAX_SPARKS := 5

## Anything with get_vector() -> Vector2; the HUD's touch joystick.
var joystick: Object
var nur: Node2D
var level := 1
var xp := 0
var xp_next := 6

var _ground: ColorRect
var _fog_mat: ShaderMaterial
var _enemies: Node2D
var _motes: Node2D
var _time := 0.0
var _spawn_acc := 0.0
var _over := false


func _ready() -> void:
	var dark := CanvasModulate.new()
	dark.color = Color(0.3, 0.33, 0.43)
	add_child(dark)

	_ground = ColorRect.new()
	_ground.size = Vector2(5200, 3600)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = GROUND_SHADER
	_ground.material = gm
	add_child(_ground)

	var tracks := Tracks.new()
	add_child(tracks)
	_motes = Node2D.new()
	add_child(_motes)
	_enemies = Node2D.new()
	add_child(_enemies)

	nur = Nur.new()
	nur.tracks = tracks
	nur.pulsed.connect(_on_pulse)
	add_child(nur)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 4.0
	nur.add_child(cam)
	cam.make_current()

	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 1
	add_child(fog_layer)
	var fog := ColorRect.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = FOG_SHADER
	fog.material = _fog_mat
	fog_layer.add_child(fog)

	var snow_layer := CanvasLayer.new()
	snow_layer.layer = 2
	add_child(snow_layer)
	var view := get_viewport().get_visible_rect().size
	snow_layer.add_child(Fx.make_snow(view, 160, 1.0))
	var near := Fx.make_snow(view, 40, 1.8)
	near.scale_amount_min = 1.2
	near.scale_amount_max = 2.0
	near.color = Color(1, 1, 1, 0.5)
	snow_layer.add_child(near)


func roll_upgrades(count: int) -> Array:
	var ids: Array = Texts.UPGRADES.keys()
	if nur.sparks >= MAX_SPARKS:
		ids.erase("spark")
	ids.shuffle()
	return ids.slice(0, count)


func apply_upgrade(id: String) -> void:
	match id:
		"radius":
			nur.pulse_radius *= 1.18
		"rate":
			nur.pulse_interval *= 0.85
		"power":
			nur.pulse_damage += 0.6
		"warmth":
			nur.max_light += 20.0
			nur.light = nur.max_light
			nur.regen += 1.0
		"speed":
			nur.speed *= 1.1
		"spark":
			nur.sparks += 1
		"pull":
			nur.pickup_radius *= 1.45


func _process(delta: float) -> void:
	if _over:
		return
	_time += delta

	var cam := get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam else nur.global_position
	_ground.global_position = (center - _ground.size * 0.5).floor()
	_fog_mat.set_shader_parameter("cam_pos", center)
	_fog_mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	_fog_mat.set_shader_parameter("clear_radius", 0.16 + 0.22 * nur.light_ratio())

	nur.move_input = joystick.get_vector() if joystick else Vector2.ZERO

	_spawn(delta)
	_touch_damage(delta)
	stats_changed.emit(nur.light_ratio(), float(xp) / xp_next)

	if nur.light <= 0.0:
		_over = true
		nur.extinguish()
		light_out.emit()


func _spawn(delta: float) -> void:
	var interval := maxf(0.26, 1.5 - _time * 0.008)
	_spawn_acc += delta
	while _spawn_acc >= interval:
		_spawn_acc -= interval
		if _enemies.get_child_count() >= MAX_ENEMIES:
			continue
		var kind := Faceless.Kind.WISP
		if _time > 70.0 and randf() < 0.25:
			kind = Faceless.Kind.TALL
		if _time > 140.0 and randf() < 0.03:
			kind = Faceless.Kind.KEEPER
		var e := Faceless.new()
		e.setup(kind, nur, _time)
		e.position = nur.global_position + Vector2.from_angle(randf() * TAU) * randf_range(1050.0, 1250.0)
		e.died.connect(_on_enemy_died)
		_enemies.add_child(e)


func _touch_damage(delta: float) -> void:
	var sparks: PackedVector2Array = nur.spark_positions()
	var body: Vector2 = nur.global_position + Vector2(0, -30)
	for e in _enemies.get_children():
		if not e.alive:
			continue
		var p: Vector2 = e.global_position + Vector2(0, -30)
		if p.distance_to(body) < e.radius + 18.0:
			nur.drain(e.drain * delta)
		for s in sparks:
			if p.distance_to(s) < e.radius + 12.0:
				e.hit(nur.spark_damage * delta)


func _on_pulse(origin: Vector2, radius: float, damage: float) -> void:
	for e in _enemies.get_children():
		if e.alive and e.global_position.distance_to(origin) <= radius + e.radius:
			e.hit(damage, origin)


func _on_enemy_died(enemy: Node2D, value: int) -> void:
	var count := 1 if value < 4 else 4
	for i in count:
		var m := Mote.new()
		m.target = nur
		m.value = value if count == 1 else value / count
		m.position = enemy.global_position + Vector2(0, -30)
		m.collected.connect(_gain_xp)
		_motes.add_child(m)


func _gain_xp(amount: int) -> void:
	if _over:
		return
	xp += amount
	if xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = int(6 + level * 3.5)
		# At most one level-up at a time; the overflow waits for the next one.
		xp = mini(xp, xp_next - 1)
		level_up.emit(level)
