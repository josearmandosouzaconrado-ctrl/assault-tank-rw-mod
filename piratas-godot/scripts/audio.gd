extends Node
## Áudio 100% procedural: efeitos sonoros e a música-tema, sintetizados ao iniciar.

const RATE := 22050

var music_on := true:
	set(v):
		music_on = v
		if _music_player:
			_music_player.volume_db = -9.0 if v else -80.0

var _streams := {}
var _players3d: Array[AudioStreamPlayer3D] = []
var _players2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _music_player: AudioStreamPlayer
var _ocean: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _thread: Thread
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	_streams["cannon"] = _make_cannon()
	_streams["splash"] = _make_splash()
	_streams["hit"] = _make_hit()
	_streams["bell"] = _make_bell()
	_streams["coin"] = _make_coin()
	_streams["click"] = _make_click()
	_streams["dig"] = _make_dig()
	_streams["ocean"] = _make_loop_noise(4.0, 0.0, true)
	_streams["wind"] = _make_loop_noise(3.0, 0.5, false)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 60.0
		p.max_distance = 1600.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		add_child(p)
		_players3d.append(p)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players2d.append(p)
	_ocean = AudioStreamPlayer.new()
	_ocean.stream = _streams["ocean"]
	_ocean.volume_db = -14.0
	add_child(_ocean)
	_wind = AudioStreamPlayer.new()
	_wind.stream = _streams["wind"]
	_wind.volume_db = -30.0
	add_child(_wind)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -9.0 if music_on else -80.0
	add_child(_music_player)
	_thread = Thread.new()
	_thread.start(_make_music)


func start_ambience() -> void:
	if not _ocean.playing:
		_ocean.play()
	if not _wind.playing:
		_wind.play()


func set_wind_level(v: float) -> void:
	if _wind:
		_wind.volume_db = lerpf(-32.0, -12.0, clampf(v, 0.0, 1.0))


func set_ocean_level(v: float) -> void:
	if _ocean:
		_ocean.volume_db = lerpf(-22.0, -8.0, clampf(v, 0.0, 1.0))


func play(id: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(id):
		return
	var p := _players2d[_next2d]
	_next2d = (_next2d + 1) % _players2d.size()
	p.stream = _streams[id]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_at(id: String, pos: Vector3, vol_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(id) or not is_inside_tree():
		return
	var p := _players3d[_next3d]
	_next3d = (_next3d + 1) % _players3d.size()
	p.stream = _streams[id]
	p.global_position = pos
	p.volume_db = vol_db
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	p.play()


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


# ------------------------------------------------------------------ síntese
func _to_wav(buf: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _make_cannon() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var k := lerpf(0.5, 0.03, minf(t * 3.0, 1.0))
		lp += (noise - lp) * k
		lp2 += (lp - lp2) * 0.2
		var env := exp(-t * 3.2) * minf(t * 400.0, 1.0)
		var thump := sin(TAU * (48.0 - t * 20.0) * t) * exp(-t * 6.0)
		b[i] = (lp2 * 2.6 + thump * 0.9) * env
	return _to_wav(b)


func _make_splash() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.35
		hp = lp - hp * 0.2
		var env := exp(-t * 4.5) * minf(t * 60.0, 1.0)
		b[i] = hp * env * 0.9
	return _to_wav(b)


func _make_hit() -> AudioStreamWAV:
	var n := int(RATE * 0.7)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.25
		var crack := sin(TAU * 140.0 * t + sin(TAU * 37.0 * t) * 3.0) * exp(-t * 9.0)
		b[i] = (lp * 1.6 * exp(-t * 7.0) + crack * 0.7)
	return _to_wav(b)


func _make_bell() -> AudioStreamWAV:
	var n := int(RATE * 2.2)
	var b := PackedFloat32Array()
	b.resize(n)
	var partials := [[1.0, 1.0], [2.76, 0.5], [5.4, 0.25], [8.93, 0.12]]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * 520.0 * p[0] * t) * p[1] * exp(-t * (1.5 + p[0] * 0.6))
		b[i] = v * 0.45
	return _to_wav(b)


func _make_coin() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 1800.0 if t < 0.08 else 2400.0
		b[i] = sin(TAU * f * t) * exp(-t * 9.0) * 0.4
	return _to_wav(b)


func _make_click() -> AudioStreamWAV:
	var n := int(RATE * 0.06)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		b[i] = sin(TAU * 900.0 * t) * exp(-t * 80.0) * 0.4
	return _to_wav(b)


func _make_dig() -> AudioStreamWAV:
	var n := int(RATE * 0.45)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.5
		b[i] = lp * exp(-t * 10.0) * 1.2
	return _to_wav(b)


func _make_loop_noise(seconds: float, brightness: float, swell: bool) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * (0.08 + brightness * 0.3)
		lp2 += (lp - lp2) * 0.3
		var mod := 1.0
		if swell:
			mod = 0.55 + 0.45 * sin(TAU * t / seconds) * sin(TAU * 2.0 * t / seconds + 1.0)
		else:
			mod = 0.7 + 0.3 * sin(TAU * t / seconds)
		b[i] = lp2 * 3.0 * mod
	# cross-fade para loop sem clique
	var fade := int(RATE * 0.25)
	for i in fade:
		var a := float(i) / fade
		b[i] = b[i] * a + b[n - fade + i] * (1.0 - a)
	b.resize(n - fade)
	return _to_wav(b, true)


# ------------------------------------------------------------------ música
# "Mares de Fortuna" — melodia original em Ré menor, compasso 6/8.
const MELODY := [
	[69, 2], [74, 1], [74, 2], [76, 1], [77, 2], [76, 1], [74, 2], [72, 1],
	[69, 2], [67, 1], [65, 2], [67, 1], [69, 6],
	[69, 2], [74, 1], [74, 2], [76, 1], [77, 2], [79, 1], [81, 2], [77, 1],
	[76, 2], [72, 1], [74, 2], [76, 1], [74, 6],
	[77, 2], [77, 1], [76, 2], [74, 1], [72, 2], [69, 1], [72, 3],
	[70, 2], [69, 1], [67, 2], [70, 1], [69, 6],
	[74, 2], [72, 1], [70, 2], [69, 1], [67, 2], [65, 1], [67, 2], [69, 1],
	[64, 2], [65, 1], [67, 2], [73, 1], [74, 6],
]
const BASS := [50, 50, 41, 45, 50, 41, 48, 50, 41, 48, 43, 45, 46, 43, 45, 50]


func _make_music() -> void:
	var rate := 16000
	var eighth := 0.19
	var total_eighths := 0
	for m in MELODY:
		total_eighths += m[1]
	var n := int(total_eighths * eighth * rate)
	var b := PackedFloat32Array()
	b.resize(n)
	# melodia: "rabeca" (dente-de-serra suave com vibrato)
	var pos := 0
	for m in MELODY:
		var f := 440.0 * pow(2.0, (m[0] - 69) / 12.0)
		var ln := int(m[1] * eighth * rate)
		var ph := 0.0
		var lp := 0.0
		for i in ln:
			if pos + i >= n:
				break
			var t := float(i) / rate
			var vib := 1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(t * 3.0, 1.0)
			ph = fmod(ph + f * vib / rate, 1.0)
			var saw := ph * 2.0 - 1.0
			lp += (saw - lp) * 0.18
			var env := minf(t * 25.0, 1.0) * (1.0 - smoothstep(ln * 0.8 / rate, float(ln) / rate, t))
			b[pos + i] += lp * env * 0.22
		pos += ln
	# baixo dedilhado + bumbo (bodhrán) em cada tempo
	var bar_len := int(6 * eighth * rate)
	for bar in BASS.size():
		for beat in 2:
			var root: int = BASS[bar] + (0 if beat == 0 else 7)
			var f := 440.0 * pow(2.0, (root - 69) / 12.0)
			var start := bar * bar_len + beat * (bar_len / 2)
			var ln := bar_len / 2
			for i in ln:
				if start + i >= n:
					break
				var t := float(i) / rate
				var v := (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * exp(-t * 3.5) * 0.2
				var drum := sin(TAU * (90.0 - t * 120.0) * t) * exp(-t * 18.0) * (0.35 if beat == 0 else 0.22)
				b[start + i] += v + drum
	call_deferred("_music_ready", _to_wav(b, true, rate))


func _music_ready(stream: AudioStreamWAV) -> void:
	_music_player.stream = stream
	_music_player.play()
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
