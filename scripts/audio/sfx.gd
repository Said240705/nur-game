extends Node
## Procedural sound: an endless wind bed plus a few synthesized one-shots.
## Nothing here needs audio files, so the prototype ships without assets.

const RATE := 22050

## 0..1, how loud the wind is. The director raises it during the Silence.
var wind_level := 0.6

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _wind_playback: AudioStreamGeneratorPlayback
var _wind_lp := 0.0
var _wind_lp2 := 0.0
var _wind_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["bell"] = _wav(_bell(523.25, 4.5, 0.55))
	_streams["pulse"] = _wav(_pulse())
	_streams["shard"] = _wav(_bell(1318.5, 0.9, 0.22))
	_streams["fade"] = _wav(_whoosh(0.7))
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.3
	var wind := AudioStreamPlayer.new()
	wind.stream = gen
	wind.volume_db = -4.0
	add_child(wind)
	wind.play()
	_wind_playback = wind.get_stream_playback()


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


func _process(_delta: float) -> void:
	if _wind_playback == null:
		return
	var frames := _wind_playback.get_frames_available()
	if frames <= 0:
		return
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		_wind_time += 1.0 / RATE
		# Two slow, unrelated waves make irregular gusts.
		var gust := 0.55 + 0.45 * sin(_wind_time * 0.37) * sin(_wind_time * 0.113 + 1.3)
		var cutoff := 0.015 + 0.05 * gust
		_wind_lp += (randf() * 2.0 - 1.0 - _wind_lp) * cutoff
		_wind_lp2 += (_wind_lp - _wind_lp2) * cutoff
		var s := _wind_lp2 * (0.5 + gust) * wind_level * 4.0
		buf[i] = Vector2(s, s)
	_wind_playback.push_buffer(buf)


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
	var partials := [[0.5, 0.35, 1.0], [1.0, 1.0, 0.8], [1.19, 0.5, 0.6], [1.56, 0.4, 0.45], [2.0, 0.3, 0.35], [2.74, 0.25, 0.25], [3.76, 0.12, 0.18]]
	var n := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for p in partials:
			s += sin(TAU * base * p[0] * t) * p[1] * exp(-t * 3.0 / (length * p[2]))
		var attack := minf(1.0, t * 400.0)
		out[i] = s * gain * 0.4 * attack
	return out


## Soft low swell for Nur's light pulse.
func _pulse() -> PackedFloat32Array:
	var n := int(0.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := sin(PI * minf(1.0, t / 0.55)) * exp(-t * 3.0)
		var freq := 196.0 - t * 60.0
		lp += (randf() * 2.0 - 1.0 - lp) * 0.08
		out[i] = (sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 1.5 * t) * 0.2 + lp * 0.5) * env * 0.6
	return out


## Breath of noise rising in pitch: a Faceless dissolving.
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
