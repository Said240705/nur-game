extends Node3D
## One run in the valley: Nur, the Faceless, memory motes and the Silence.
## The director (main.gd) listens to the signals and handles every pause.

signal level_up(level: int)
signal light_out
signal stats_changed(light: float, xp: float)

const Texts := preload("res://scripts/texts.gd")
const Nur := preload("res://scripts/game/nur.gd")
const Faceless := preload("res://scripts/game/faceless.gd")
const Mote := preload("res://scripts/game/mote.gd")
const Tracks := preload("res://scripts/game/tracks.gd")

const MAX_ENEMIES := 70
const MAX_SPARKS := 5
const START := Vector3(0, 0, 6)

## The valley this run takes place in (scripts/world/world.gd).
var world: Node3D
## Anything with get_vector() -> Vector2; the HUD's touch joystick.
var joystick: Object
var nur: Node3D
var level := 1
var xp := 0
var xp_next := 6

var _enemies: Node3D
var _motes: Node3D
var _time := 0.0
var _spawn_acc := 0.0
var _over := false


func _ready() -> void:
	var tracks := Tracks.new()
	add_child(tracks)
	_motes = Node3D.new()
	add_child(_motes)
	_enemies = Node3D.new()
	add_child(_enemies)

	nur = Nur.new()
	nur.tracks = tracks
	nur.position = START
	nur.pulsed.connect(_on_pulse)
	add_child(nur)


func enemy_count() -> int:
	return _enemies.get_child_count()


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
	nur.move_input = joystick.get_vector() if joystick else Vector2.ZERO
	if world:
		world.set_silence(nur.light_ratio())

	_spawn(delta)
	_touch_damage(delta)
	stats_changed.emit(nur.light_ratio(), float(xp) / xp_next)

	if nur.light <= 0.0:
		_over = true
		nur.extinguish()
		light_out.emit()


func _spawn(delta: float) -> void:
	# A short calm at the start, so the first steps out of the village feel quiet.
	if _time < 4.0:
		return
	var interval := maxf(0.4, 1.6 - _time * 0.008)
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
		var a := randf() * TAU
		e.position = nur.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(22.0, 28.0)
		e.died.connect(_on_enemy_died)
		_enemies.add_child(e)


func _touch_damage(delta: float) -> void:
	var sparks: PackedVector3Array = nur.spark_positions()
	var body: Vector3 = nur.global_position
	for e in _enemies.get_children():
		if not e.alive:
			continue
		var p: Vector3 = e.global_position
		var flat := Vector2(p.x - body.x, p.z - body.z).length()
		if flat < e.radius + 0.35:
			nur.drain(e.drain * delta)
		for s in sparks:
			if Vector2(p.x - s.x, p.z - s.z).length() < e.radius + 0.25:
				e.hit(nur.spark_damage * delta)


func _on_pulse(origin: Vector3, radius: float, damage: float) -> void:
	for e in _enemies.get_children():
		if not e.alive:
			continue
		var p: Vector3 = e.global_position
		if Vector2(p.x - origin.x, p.z - origin.z).length() <= radius + e.radius:
			e.hit(damage, origin)


func _on_enemy_died(enemy: Node3D, value: int) -> void:
	var count := 1 if value < 4 else 4
	for i in count:
		var m := Mote.new()
		m.target = nur
		m.value = value if count == 1 else value / count
		m.position = Vector3(enemy.global_position.x, 0, enemy.global_position.z)
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
