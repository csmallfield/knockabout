extends Node
## All juice hangs off EventBus.impact_occurred (GDD §12) — feel scales
## with physics for free. Hit-stop, camera shake (via player), placeholder SFX.

var _last_hitstop := 0.0
var _players: Array[AudioStreamPlayer] = []
var _sfx := {}   # name -> AudioStreamWAV

func _ready() -> void:
	EventBus.impact_occurred.connect(_on_impact)
	EventBus.entity_died.connect(_on_died)
	_sfx["thud"] = _make_blip(90.0, 0.10, 0.2)
	_sfx["crack"] = _make_blip(240.0, 0.07, 0.7)
	_sfx["break"] = _make_blip(120.0, 0.22, 0.9)
	_sfx["whoosh"] = _make_blip(400.0, 0.12, 0.5)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

func _on_impact(event: ImpactEvent, damage: float) -> void:
	# Hit-stop: none < 8 dmg; 2 frames @8 → 5 frames @30+; stack-capped 0.1 s.
	if damage >= 8.0:
		var frames := int(remap(clampf(damage, 8.0, 30.0), 8.0, 30.0, 2.0, 5.0))
		_hitstop(frames)
	# Trauma per impact energy proxy (damage), capped in the camera.
	if damage > 0.0:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.add_trauma(clampf(damage / 40.0, 0.05, 0.5))
		_play(_sfx["crack"] if damage > 12.0 else _sfx["thud"])
	elif event.rel_velocity.length() > Tuning.MIN_IMPACT_SPEED:
		_play(_sfx["whoosh"], -16.0)

func _on_died(_entity: Node, _stats: PhysicsStats, _map: String) -> void:
	_play(_sfx["break"])

func _hitstop(frames: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hitstop < 0.1:
		return
	_last_hitstop = now
	Engine.time_scale = 0.05
	# Real-time timer (ignores time_scale) so we always recover.
	await get_tree().create_timer(frames / 60.0, true, false, true).timeout
	Engine.time_scale = 1.0

func _play(stream: AudioStream, vol := -8.0) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = vol
			p.pitch_scale = randf_range(0.9, 1.1)   # ±10% (§12)
			p.play()
			return

## Generated placeholder blip: decaying sine + noise mix, 16-bit mono.
func _make_blip(freq: float, dur: float, noise_amount: float) -> AudioStreamWAV:
	var rate := 22050
	var samples := int(dur * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / rate
		var env := pow(1.0 - float(i) / samples, 2.0)
		var s := sin(TAU * freq * t) * (1.0 - noise_amount) \
			+ randf_range(-1.0, 1.0) * noise_amount
		var v := int(clampf(s * env, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
