extends Node
## Zvukové efekty generované přímo v kódu (žádné soubory nejsou potřeba).

const RATE := 22050

var sounds := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	sounds["jump"] = _tone(260.0, 620.0, 0.14, 0.18)
	sounds["swing"] = _noise(0.12, 0.22, 2)
	sounds["stomp"] = _tone(320.0, 80.0, 0.18, 0.25)
	sounds["hurt"] = _tone(400.0, 120.0, 0.3, 0.25)
	sounds["die"] = _tone(500.0, 60.0, 0.7, 0.25)
	sounds["pickup"] = _arp([660.0, 990.0], 0.06, 0.16)
	sounds["bonus"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.07, 0.18)
	sounds["checkpoint"] = _arp([392.0, 523.0, 659.0], 0.09, 0.18)
	sounds["win"] = _arp([523.0, 659.0, 784.0, 659.0, 784.0, 1046.0], 0.11, 0.2)
	sounds["select"] = _tone(700.0, 700.0, 0.05, 0.12)
	sounds["land"] = _noise(0.06, 0.08, 6)
	sounds["hit"] = _mix(_noise_arr(0.09, 0.35, 3), _tone_arr(180.0, 70.0, 0.09, 0.3))
	sounds["heavy"] = _mix(_noise_arr(0.22, 0.4, 5), _tone_arr(120.0, 40.0, 0.22, 0.4))
	sounds["dodge"] = _noise(0.14, 0.15, 1)
	sounds["break"] = _noise(0.25, 0.35, 9)
	sounds["magic"] = _arp([220.0, 330.0, 440.0, 660.0, 880.0], 0.05, 0.16)
	sounds["thunder"] = _mix(_noise_arr(0.8, 0.5, 14), _tone_arr(90.0, 30.0, 0.8, 0.35))
	sounds["roar"] = _mix(_noise_arr(0.6, 0.25, 11), _tone_arr(110.0, 70.0, 0.6, 0.3))
	sounds["go"] = _arp([523.0, 784.0], 0.1, 0.15)


func play(sound_name: String, pitch: float = 1.0) -> void:
	if not sounds.has(sound_name):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[sound_name]
	p.pitch_scale = pitch
	p.play()


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


## Obdélníková vlna s plynulou změnou výšky tónu.
func _tone(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		var v := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		s[i] = v * vol * (1.0 - t)
	return _wav(s)


func _noise(dur: float, vol: float, hold: int) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var v := 0.0
	for i in n:
		if i % hold == 0:
			v = randf() * 2.0 - 1.0
		s[i] = v * vol * (1.0 - float(i) / n)
	return _wav(s)


func _arp(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var per := int(RATE * step)
	var s := PackedFloat32Array()
	s.resize(per * freqs.size())
	var phase := 0.0
	for k in freqs.size():
		var f: float = freqs[k]
		for i in per:
			phase += f / RATE
			var t := float(i) / per
			var v := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			s[k * per + i] = v * vol * (1.0 - t * 0.6)
	return _wav(s)


func _tone_arr(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / RATE
		s[i] = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * vol * (1.0 - t) * (1.0 - t)
	return s


func _noise_arr(dur: float, vol: float, hold: int) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var v := 0.0
	for i in n:
		if i % hold == 0:
			v = randf() * 2.0 - 1.0
		var t := float(i) / n
		s[i] = v * vol * (1.0 - t) * (1.0 - t)
	return s


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> AudioStreamWAV:
	var n := maxi(a.size(), b.size())
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		s[i] = v
	return _wav(s)
