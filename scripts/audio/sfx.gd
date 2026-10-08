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
	_streams["click"] = _wav(_tones([[880.0, 0.0]], 0.08, 0.15, 50.0))
	_streams["no"] = _wav(_tones([[330.0, 0.0], [262.0, 0.07]], 0.3, 0.22, 14.0))
	# Ore tipped into a crate.
	_streams["drop"] = _wav(_thock())
	# The lift arriving at the top.
	_streams["ding"] = _wav(_tones([[1318.5, 0.0], [1760.0, 0.12]], 0.9, 0.12, 5.0))
	# Coins: a bright cha-ching.
	_streams["coin"] = _wav(_tones([[1975.5, 0.0], [2637.0, 0.07]], 0.5, 0.16, 9.0))
	_streams["up"] = _wav(_tones([[784.0, 0.0], [988.0, 0.06], [1175.0, 0.12]], 0.6, 0.18, 8.0))
	_streams["fanfare"] = _wav(_tones([[523.3, 0.0], [659.3, 0.1], [784.0, 0.2], [1046.5, 0.3], [1318.5, 0.42]], 1.6, 0.2, 3.0))
	_streams["boost"] = _wav(_sparkle())
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
