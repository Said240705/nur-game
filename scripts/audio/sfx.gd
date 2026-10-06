extends Node
## Procedural sound: an endless rain bed plus synthesized phone and door sounds,
## and the music tracks in assets/audio/music (made by tools/music/make_music.py).

const RATE := 22050
const MUSIC := {
	"theme": preload("res://assets/audio/music/theme.ogg"),
	"lonely": preload("res://assets/audio/music/lonely.ogg"),
	"tension": preload("res://assets/audio/music/tension.ogg"),
	"dread": preload("res://assets/audio/music/dread.ogg"),
}
## How loud music sits under the rain and the phone sounds.
const MUSIC_DB := -10.0

## 0..1, how loud the rain is. Indoors it is muffled, outside it pours.
var rain_level := 0.5
## 0..1, how much the rain is muffled (0 = outside, 1 = behind a closed window).
var rain_muffle := 0.6

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _rain_playback: AudioStreamGeneratorPlayback
var _lp := 0.0
var _lp2 := 0.0
var _drops := 0.0
var _time := 0.0
## Two players so one track can fade out while the next fades in.
var _music: Array[AudioStreamPlayer] = []
var _current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["bell"] = _wav(_bell(523.25, 4.5, 0.5))
	_streams["ping"] = _wav(_tones([[1318.5, 0.0], [1760.0, 0.09]], 0.5, 0.25))
	_streams["doorbell"] = _wav(_tones([[659.25, 0.0], [523.25, 0.55]], 1.8, 0.45))
	_streams["buzz"] = _wav(_buzz())
	_streams["click"] = _wav(_click())
	_streams["error"] = _wav(_tones([[220.0, 0.0], [196.0, 0.12]], 0.4, 0.3))
	_streams["unlock"] = _wav(_tones([[880.0, 0.0], [1174.7, 0.08], [1568.0, 0.16]], 0.8, 0.22))
	_streams["whoosh"] = _wav(_whoosh(0.9))
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	for key in ["theme", "lonely", "tension"]:
		(MUSIC[key] as AudioStreamOggVorbis).loop = true

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.3
	var rain := AudioStreamPlayer.new()
	rain.stream = gen
	rain.volume_db = -6.0
	add_child(rain)
	rain.play()
	_rain_playback = rain.get_stream_playback()


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


## Crossfade to a music track ("" for silence). Looping tracks keep playing;
## "dread" plays once.
func music(track: String, fade := 2.5, volume_db := MUSIC_DB) -> void:
	if track == _current:
		return
	_current = track
	var old: AudioStreamPlayer = _music[0]
	var new: AudioStreamPlayer = _music[1]
	_music.reverse()
	if old.playing:
		var out := create_tween()
		out.tween_property(old, "volume_db", -80.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		out.tween_callback(old.stop)
	if track == "":
		return
	new.stream = MUSIC[track]
	new.volume_db = -40.0
	new.play()
	create_tween().tween_property(new, "volume_db", volume_db, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	if _rain_playback == null:
		return
	var frames := _rain_playback.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	var cutoff := lerpf(0.55, 0.08, rain_muffle)
	for i in frames:
		_time += 1.0 / RATE
		# Steady hiss from countless drops...
		_lp += (randf() * 2.0 - 1.0 - _lp) * cutoff
		_lp2 += (_lp - _lp2) * cutoff
		# ...plus the odd heavy drop tapping on glass or a sill.
		if randf() < 0.0009:
			_drops = randf_range(0.3, 0.8)
		_drops *= 0.985
		var tap := (randf() * 2.0 - 1.0) * _drops * (1.0 - rain_muffle * 0.6)
		var swell := 0.85 + 0.15 * sin(_time * 0.21)
		var s := (_lp2 * 2.2 + tap * 0.35) * rain_level * swell
		buf[i] = Vector2(s, s * 0.96)
	_rain_playback.push_buffer(buf)


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## Inharmonic partials with independent decays read as a small metal bell.
func _bell(base: float, length: float, gain: float) -> PackedFloat32Array:
	var partials := [[0.5, 0.35, 1.0], [1.0, 1.0, 0.8], [1.19, 0.5, 0.6], [1.56, 0.4, 0.45], [2.0, 0.3, 0.35], [2.74, 0.25, 0.25]]
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * base * p[0] * t) * p[1] * exp(-t * 3.0 / (length * p[2]))
		out[i] = s * gain * 0.4 * minf(1.0, t * 400.0)
	return out


## Soft sine notes [frequency, start] each fading out: phone pings, the door chime.
func _tones(notes: Array, length: float, gain: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for note in notes:
			var lt: float = t - note[1]
			if lt >= 0.0:
				var env := minf(1.0, lt * 300.0) * exp(-lt * 4.0)
				s += (sin(TAU * note[0] * lt) + 0.25 * sin(TAU * note[0] * 2.0 * lt)) * env
		out[i] = s * gain
	return out


## Two short rattling pulses of a phone vibrating on a wooden desk.
func _buzz() -> PackedFloat32Array:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var on := 1.0 if fmod(t, 0.45) < 0.32 else 0.0
		var rattle := sin(TAU * 165.0 * t) * 0.7 + sin(TAU * 330.0 * t) * 0.2 + (randf() - 0.5) * 0.25
		out[i] = rattle * on * 0.5
	return out


func _click() -> PackedFloat32Array:
	var n := int(0.04 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (randf() * 2.0 - 1.0) * exp(-t * 180.0) * 0.5
	return out


## Breath of noise rising in pitch, for cuts and transitions.
func _whoosh(length: float) -> PackedFloat32Array:
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / length
		lp += (randf() * 2.0 - 1.0 - lp) * (0.02 + 0.25 * k)
		out[i] = lp * sin(PI * k) * 1.2
	return out
