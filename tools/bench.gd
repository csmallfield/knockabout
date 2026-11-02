class_name Bench
extends Node
## Headless crowd bench. Run:
##   godot --headless --path . -- --bench --mobs=60 [--bench-time=15] [--puppet-off]
## Spawns N mobs round the player, keeps the player alive and swinging so the
## knock physics run, then prints frame-cost averages after a warm-up.
## Headless numbers are CPU cost only (script + physics), never frame rate.

var mobs := 60
var duration := 15.0
var warmup := 2.0
var _t := 0.0
var _started := false
var _samples_proc := PackedFloat32Array()
var _samples_phys := PackedFloat32Array()
var _samples_draw := PackedFloat32Array()
var _swing_t := 0.0
var _respawn_t := 0.0
var _shots := ""
var _shot_t := 0.0
var _shot_n := 0
var _wall_start := 0
var _frames := 0

static func requested() -> bool:
	return OS.get_cmdline_user_args().has("--bench")

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mobs="):
			mobs = int(a.get_slice("=", 1))
		elif a.begins_with("--shots="):
			_shots = a.get_slice("=", 1)
		elif a == "--no-pose":
			MobPuppet.frozen = true
		elif a.begins_with("--bench-time="):
			duration = float(a.get_slice("=", 1))
	process_priority = 1000

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or MapManager.current_map == null:
		return
	if not _started:
		_started = true
		_spawn(player, mobs)
		return
	_t += delta
	player.heal_full()
	# Keep the fight going: swing on a beat, walk a slow circle.
	_swing_t -= delta
	if _swing_t <= 0.0:
		_swing_t = 0.35
		Input.action_press("attack")
	else:
		Input.action_release("attack")
	var a := _t * 0.8
	Input.action_press("move_right", maxf(cos(a), 0.0))
	Input.action_press("move_left", maxf(-cos(a), 0.0))
	Input.action_press("move_down", maxf(sin(a), 0.0))
	Input.action_press("move_up", maxf(-sin(a), 0.0))
	# Top the crowd back up as mobs die so N stays roughly constant.
	_respawn_t -= delta
	if _respawn_t <= 0.0:
		_respawn_t = 0.5
		var alive := get_tree().get_nodes_in_group("mobs").size()
		if alive < mobs:
			_spawn(player, mobs - alive)
	if _shots != "":
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = 0.25
			get_viewport().get_texture().get_image().save_png("%s_%02d.png" % [_shots, _shot_n])
			_shot_n += 1
	if _t < warmup:
		return
	if _wall_start == 0:
		_wall_start = Time.get_ticks_usec()
		MobPuppet.total_poses = 0
		MobPuppet.total_usec = 0

	_frames += 1
	_samples_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_samples_phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_samples_draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _t >= warmup + duration:
		_report()
		get_tree().quit()

func _spawn(player: Node2D, n: int) -> void:
	var map := MapManager.current_map
	var b := map.bounds.grow(-64.0)
	var ids := ["goblin", "goblin", "orc", "brute"]
	for i in n:
		var node := Registry.spawn(ids[i % ids.size()])
		if node == null:
			continue
		map.entities.add_child(node)
		var p := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(80.0, 260.0)
		node.global_position = Vector2(clampf(p.x, b.position.x, b.end.x), clampf(p.y, b.position.y, b.end.y))

func _report() -> void:
	var mobs_alive := get_tree().get_nodes_in_group("mobs").size()
	print("BENCH mobs=%d (alive at end %d) frames=%d" % [mobs, mobs_alive, _samples_proc.size()])
	print("BENCH wall     %.2f ms per frame (all CPU work, headless)" % [(Time.get_ticks_usec() - _wall_start) / 1000.0 / maxf(_frames, 1)])
	if MobPuppet.total_poses > 0:
		print("BENCH puppets  %.2f ms per frame posing, %.1f poses per frame, %.1f us per pose" % [
			MobPuppet.total_usec / 1000.0 / maxf(_frames, 1), float(MobPuppet.total_poses) / maxf(_frames, 1),
			float(MobPuppet.total_usec) / MobPuppet.total_poses])
	print("BENCH draw calls avg %.0f (0 headless)" % _avg(_samples_draw))

func _avg(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)

func _p95(a: PackedFloat32Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[int(b.size() * 0.95)] if b.size() > 0 else 0.0
