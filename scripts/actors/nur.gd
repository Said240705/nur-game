extends Node2D
## Nur, drawn from her character sheet. One painted view per direction (front,
## back, side) brought to life with a procedural walk: bob, sway and lean.
## World units are pixels of the original 1536x1024 village painting.

const Fx := preload("res://scripts/fx.gd")
const FRONT := preload("res://assets/art/nur/front.png")
const BACK := preload("res://assets/art/nur/back.png")
const SIDE := preload("res://assets/art/nur/side.png")
const HEIGHT := 118.0
const GLOW := Color(1.0, 0.68, 0.38)

## Joystick direction (length <= 1), set by the village every frame.
var move_input := Vector2.ZERO
var speed := 120.0
var tracks: Node2D
## Callable(Vector2) -> bool telling whether a point is walkable.
var can_walk: Callable
var frozen := false

var _body: Node2D
var _sprite: Sprite2D
var _lamp: PointLight2D
var _vel := Vector2.ZERO
var _walk := 0.0
var _t := 0.0
var _step_acc := 0.0
var _step_side := 1.0


func _ready() -> void:
	# The body pivots at the feet, so leaning and swaying look grounded.
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_body.add_child(_sprite)
	_set_view(FRONT, false)

	_lamp = PointLight2D.new()
	_lamp.texture = Fx.radial_texture(256)
	_lamp.color = GLOW
	_lamp.energy = 0.9
	_lamp.texture_scale = 1.6
	_lamp.position = Vector2(0, -HEIGHT * 0.55)
	add_child(_lamp)


## Turn to face a point, used when a conversation starts.
func face(point: Vector2) -> void:
	var d := point - global_position
	if absf(d.x) > absf(d.y):
		_set_view(SIDE, d.x > 0.0)
	elif d.y < 0.0:
		_set_view(BACK, false)
	else:
		_set_view(FRONT, false)


func _process(delta: float) -> void:
	_t += delta
	var wish := Vector2.ZERO if frozen else (move_input + _keyboard()).limit_length(1.0)
	_vel = _vel.lerp(wish * speed, minf(1.0, delta * 10.0))
	var step := _vel * delta
	if can_walk.is_valid():
		# Slide along walls: try the full move, then each axis on its own.
		if not can_walk.call(position + step):
			if can_walk.call(position + Vector2(step.x, 0)):
				step = Vector2(step.x, 0)
			elif can_walk.call(position + Vector2(0, step.y)):
				step = Vector2(0, step.y)
			else:
				step = Vector2.ZERO
				_vel = Vector2.ZERO
	position += step

	var moving := _vel.length()
	if moving > 8.0:
		if absf(_vel.x) > absf(_vel.y) * 0.8:
			_set_view(SIDE, _vel.x > 0.0)
		elif _vel.y < 0.0:
			_set_view(BACK, false)
		else:
			_set_view(FRONT, false)
		_walk += delta * moving / 9.0
	else:
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, minf(1.0, delta * 8.0))

	# Procedural walk: a little hop each step, a sway of the cloak, a lean into motion.
	var k := clampf(moving / speed, 0.0, 1.0)
	var hop := absf(sin(_walk)) * 3.5 * k
	var breathe := sin(_t * 2.2) * 0.012
	_body.position.y = -hop
	_body.rotation = sin(_walk) * 0.035 * k + clampf(_vel.x / speed, -1.0, 1.0) * 0.03
	var s := _base_scale()
	_sprite.scale = Vector2(s * (1.0 - breathe * 0.5), s * (1.0 + breathe + absf(cos(_walk)) * 0.02 * k))
	_sprite.position.y = -_sprite.texture.get_height() * _sprite.scale.y
	_lamp.energy = 0.85 + sin(_t * 2.6) * 0.06

	if moving > 30.0 and tracks:
		_step_acc += moving * delta
		if _step_acc > 16.0:
			_step_acc = 0.0
			_step_side = -_step_side
			tracks.add(position + _vel.orthogonal().normalized() * 4.0 * _step_side, _vel.angle())


func _base_scale() -> float:
	return HEIGHT / float(_sprite.texture.get_height())


func _set_view(tex: Texture2D, flip: bool) -> void:
	# The side view on the sheet faces left; flip it to walk right.
	var f := flip if tex == SIDE else false
	if _sprite.texture == tex and _sprite.flip_h == f:
		return
	_sprite.texture = tex
	_sprite.flip_h = f
	var s := _base_scale()
	_sprite.scale = Vector2(s, s)
	_sprite.offset = Vector2(-tex.get_width() * 0.5, 0)
	_sprite.position.y = -tex.get_height() * s


func _keyboard() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1
	return v
