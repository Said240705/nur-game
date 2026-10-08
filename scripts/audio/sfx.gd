extends Node
## Every sound is synthesized here at start-up (no sound files), plus the calm
## background loop made by tools/music/make_music.py.

const RATE := 22050
const MUSIC := preload("res://assets/audio/music/ambient.ogg")
const MUSIC_DB := -13.0

var sound_on := true
var music_on := true

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["pick"] = _wav(_tones([[1560.0, 0.0]], 0.08, 0.18, 60.0))
	_streams["place"] = _wav(_thock())
	_streams["miss"] = _wav(_tones([[330.0, 0.0], [262.0, 0.07]], 0.3, 0.22, 14.0))
	# A rising chime; the pitch climbs with the combo.
	_streams["clear"] = _wav(_tones([[1046.5, 0.0], [1318.5, 0.05], [1568.0, 0.1], [2093.0, 0.15]], 0.9, 0.2, 6.0))
	_streams["big"] = _wav(_sparkle())
	_streams["deal"] = _wav(_swoosh())
	_streams["over"] = _wav(_tones([[523.3, 0.0], [440.0, 0.18], [349.2, 0.36], [261.6, 0.56]], 1.6, 0.22, 3.5))
	_streams["record"] = _wav(_tones([[523.3, 0.0], [659.3, 0.1], [784.0, 0.2], [1046.5, 0.3], [1318.5, 0.42]], 1.6, 0.2, 3.0))
	_streams["click"] = _wav(_tones([[880.0, 0.0]], 0.08, 0.15, 50.0))
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var loop: AudioStreamOggVorbis = MUSIC
	loop.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = loop
	_music.volume_db = -80.0
	add_child(_music)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not sound_on or not _streams.has(sound):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Starts or stops the background loop with a gentle fade.
func set_music(on: bool) -> void:
	music_on = on
	var tw := create_tween()
	if on:
		if not _music.playing:
			_music.play()
		tw.tween_property(_music, "volume_db", MUSIC_DB, 2.5).set_trans(Tween.TRANS_SINE)
	else:
		tw.tween_property(_music, "volume_db", -80.0, 0.8)
		tw.tween_callback(_music.stop)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w


## Soft bell-like notes [frequency, start], each fading at `decay`.
func _tones(notes: Array, length: float, gain: float, decay: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for note in notes:
			var lt: float = t - note[1]
			if lt >= 0.0:
				var env := minf(1.0, lt * 400.0) * exp(-lt * decay)
				s += (sin(TAU * note[0] * lt) + 0.3 * sin(TAU * note[0] * 2.0 * lt) + 0.1 * sin(TAU * note[0] * 3.0 * lt)) * env
		out[i] = s * gain
	return out


## A block landing: a soft low knock with a glassy tick on top.
func _thock() -> PackedFloat32Array:
	var n := int(0.18 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (90.0 + 160.0 * exp(-t * 40.0)) / RATE
		var body := sin(phase) * exp(-t * 26.0)
		var tick := sin(TAU * 2400.0 * t) * exp(-t * 120.0) * 0.25
		out[i] = (body * 0.6 + tick) * minf(1.0, t * 2000.0)
	return out


## Glittering high notes for a big clear.
func _sparkle() -> PackedFloat32Array:
	var n := int(1.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := []
	var scale := [2093.0, 2349.3, 2637.0, 3136.0, 3520.0, 4186.0]
	for k in 14:
		notes.append([scale[randi() % scale.size()], k * 0.045])
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for note in notes:
			var lt: float = t - note[1]
			if lt >= 0.0:
				s += sin(TAU * note[0] * lt) * exp(-lt * 9.0)
		out[i] = s * 0.06
	return out


## Air rushing past, for new pieces sliding in.
func _swoosh() -> PackedFloat32Array:
	var n := int(0.35 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		lp += (randf() * 2.0 - 1.0 - lp) * (0.05 + 0.3 * k)
		out[i] = lp * sin(PI * k) * 0.5
	return out
