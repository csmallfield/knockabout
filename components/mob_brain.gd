class_name MobBrain
extends Node
## Context-steering AI brain (GDD §7, replacing straight-line pursuit).
##
## Lives only inside the GROUNDED window: MobBase calls think() each physics
## tick while controllable and interrupt() the moment the body is launched. The
## brain NEVER moves the body or deals damage directly — it returns a desired
## velocity (intent) and asks the owner to strike. The resolver / BallisticMotion
## keep full authority, exactly as before.
##
## States (all within GROUNDED): IDLE → CHASE → STRAFE → WINDUP → STRIKE →
## RECOVER, plus optional FLEE. Movement is context steering: N candidate
## directions, each scored by interest (weighted goals) minus danger (whisker
## rays vs walls/props), pick the best unblocked slot.

enum State { IDLE, CHASE, STRAFE, WINDUP, STRIKE, RECOVER, FLEE }

const SLOT_COUNT := 16
const TURN_RATE := 9.0       ## heading smoothing (higher = snappier turns)
const DANGER_WEIGHT := 1.5   ## how hard danger pushes against interest
const DANGER_BLOCK := 0.85   ## slots at/above this are hard-rejected
const LOOKAHEAD_PAD := 40.0  ## whisker length beyond the body radius

var state := State.IDLE

var _owner: Node          # MobBase
var _body: CharacterBody2D
var _stats: PhysicsStats
var brain: BrainProfile

var _slots: Array[Vector2] = []
var _danger: PackedFloat32Array
var _look_ahead := 40.0
var _heading := Vector2.DOWN

var _home := Vector2.ZERO
var _home_set := false

var _target: Node2D
var _has_target := false
var _visible_now := false
var _awareness := 0.0
var _last_seen := Vector2.ZERO
var _lose_timer := 0.0
var _perc_timer := 0.0

var _state_time := 0.0
var _cooldown := 0.0          # post-attack lockout (owner.contact_cooldown)
var _has_token := false
var _strafe_sign := 1.0
var _dash_dir := Vector2.ZERO
var _strike_done := false
var _charge_stunned := false
var _recover_override := 0.0

var _dodge_dir := Vector2.ZERO
var _dodge_timer := 0.0

var _wander_dir := Vector2.RIGHT
var _wander_timer := 0.0

# ------------------------------------------------------------------ lifecycle

func setup(owner: Node) -> void:
	_owner = owner
	_body = owner as CharacterBody2D
	_stats = owner.stats
	brain = owner.profile.brain
	if brain == null:
		# Backward-compatible default: behave like the old beeliner, but smarter.
		brain = BrainProfile.new()
		brain.sense_radius = owner.aggro_radius
	for i in SLOT_COUNT:
		_slots.append(Vector2.RIGHT.rotated(TAU * float(i) / float(SLOT_COUNT)))
	_danger = PackedFloat32Array()
	_danger.resize(SLOT_COUNT)
	_look_ahead = owner.radius + LOOKAHEAD_PAD
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_perc_timer = randf() * Tuning.AI_PERCEPTION_INTERVAL   # desync the herd

func _exit_tree() -> void:
	_release_token()

## Body was launched / stunned: bail out of any committed action cleanly.
func interrupt() -> void:
	_release_token()
	_strike_done = false
	_charge_stunned = false
	_recover_override = 0.0
	_dodge_timer = 0.0
	if state in [State.WINDUP, State.STRIKE, State.RECOVER]:
		_set_state(State.STRAFE if _has_target else State.IDLE)

# --------------------------------------------------------------------- think

## Returns the desired velocity for this physics tick.
func think(delta: float) -> Vector2:
	if not _home_set:
		_home = _body.global_position
		_home_set = true
	_state_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)

	_perception(delta)
	_maybe_dodge()

	if _dodge_timer > 0.0 and state != State.WINDUP and state != State.STRIKE:
		var dodge_goals: Array = [{"dir": _dodge_dir, "weight": 2.0}]
		dodge_goals += _separation_goals()
		return _steer(dodge_goals, brain.dodge_speed, delta)

	match state:
		State.IDLE: return _idle(delta)
		State.CHASE: return _chase(delta)
		State.STRAFE: return _strafe(delta)
		State.WINDUP: return _windup(delta)
		State.STRIKE: return _strike_state(delta)
		State.RECOVER: return _recover(delta)
		State.FLEE: return _flee(delta)
	return Vector2.ZERO

# --------------------------------------------------------------------- states

func _idle(delta: float) -> Vector2:
	if _has_target:
		_set_state(State.CHASE)
		return _pursue(_owner.walk_speed, delta)
	_owner.face_dir = _heading
	return _wander(delta)

func _chase(delta: float) -> Vector2:
	if not _has_target:
		_set_state(State.IDLE)
		return _wander(delta)
	if _should_flee():
		_set_state(State.FLEE)
		return _flee(delta)
	var to := _seek_pos() - _body.global_position
	if _visible_now and to.length() <= brain.engage_distance + brain.engage_tolerance:
		_set_state(State.STRAFE)
	return _pursue(_owner.walk_speed, delta)

func _strafe(delta: float) -> Vector2:
	if not _has_target:
		_set_state(State.IDLE); return _wander(delta)
	if _should_flee():
		_set_state(State.FLEE); return _flee(delta)
	if not _visible_now:
		_set_state(State.CHASE); return _pursue(_owner.walk_speed, delta)

	var to := _target.global_position - _body.global_position
	var dist := to.length()
	var dir := to.normalized()
	_owner.face_dir = dir

	if dist > brain.engage_distance + brain.engage_tolerance * 2.0:
		_set_state(State.CHASE)
		return _pursue(_owner.walk_speed, delta)

	# Commit to an attack only with a token, off cooldown, after a short dwell
	# (dwell shrinks with aggression — orcs barely circle, goblins flit).
	var dwell := lerpf(0.55, 0.0, brain.aggression)
	if _has_token or CombatDirector.request_token(_owner):
		_has_token = true
		if _cooldown <= 0.0 and _state_time >= dwell \
				and dist <= brain.engage_distance + brain.engage_tolerance:
			_set_state(State.WINDUP)
			return Vector2.ZERO

	var goals: Array = [{"dir": Vector2(-dir.y, dir.x) * _strafe_sign, "weight": 1.0}]
	if dist < brain.engage_distance - brain.engage_tolerance:
		goals.append({"dir": -dir, "weight": 1.2})       # too close → ease out
	elif dist > brain.engage_distance:
		goals.append({"dir": dir, "weight": 0.8})         # drift back in
	goals += _separation_goals()
	return _steer(goals, _owner.walk_speed * brain.strafe_speed_factor, delta)

func _windup(delta: float) -> Vector2:
	if not _has_target or not _visible_now or _target == null:
		_begin_recover(false)
		return Vector2.ZERO
	var to := _target.global_position - _body.global_position
	if to.length() > 1.0:
		_owner.face_dir = to.normalized()
	if _state_time >= brain.windup_time:
		_dash_dir = _owner.face_dir
		if _dash_dir == Vector2.ZERO:
			_dash_dir = Vector2.DOWN
		_strike_done = false
		_set_state(State.STRIKE)
	return Vector2.ZERO   # rooted telegraph (the orange tell is drawn by MobBase)

func _strike_state(delta: float) -> Vector2:
	if _strike_done:
		return Vector2.ZERO
	match brain.attack_style:
		BrainProfile.AttackStyle.CONTACT:
			if _target:
				var to := _target.global_position - _body.global_position
				if to.length() > 1.0:
					_owner.face_dir = to.normalized()
			if _owner.try_strike():
				_strike_done = true
				_begin_recover(false)
				return Vector2.ZERO
			if _state_time >= 0.2:
				_begin_recover(false)
				return Vector2.ZERO
			return _owner.face_dir * _owner.walk_speed * 0.9
		_:
			# LUNGE / CHARGE: commit straight down the locked aim.
			if _owner.try_strike():
				_strike_done = true
				_begin_recover(false)
				return _dash_dir * brain.dash_speed * 0.25
			if brain.attack_style == BrainProfile.AttackStyle.CHARGE \
					and _state_time > 0.06 \
					and _body.get_real_velocity().length() < brain.dash_speed * 0.4:
				_begin_recover(true)   # slammed a wall → self-stun payoff
				return Vector2.ZERO
			if _state_time >= brain.dash_time:
				_begin_recover(false)
				return Vector2.ZERO
			return _dash_dir * brain.dash_speed

func _recover(delta: float) -> Vector2:
	var rt: float = _recover_override if _recover_override > 0.0 else brain.recover_time
	if _state_time >= rt:
		_release_token()
		_charge_stunned = false
		_recover_override = 0.0
		_set_state(State.STRAFE if _has_target else State.IDLE)
		return Vector2.ZERO
	if _charge_stunned:
		return Vector2.ZERO   # dazed: a free window for the player
	var goals := _separation_goals()
	if _target:
		var away := _body.global_position - _target.global_position
		if away.length() > 1.0:
			_owner.face_dir = (-away).normalized()   # keep eyes on the player
			goals.append({"dir": away.normalized(), "weight": 1.0})
	return _steer(goals, _owner.walk_speed * 0.55, delta)

func _flee(delta: float) -> Vector2:
	if not _has_target or _owner.hp_ratio() > minf(brain.flee_below_hp + 0.2, 1.0):
		_set_state(State.CHASE if _has_target else State.IDLE)
	var goals := _separation_goals()
	if _target:
		var away := _body.global_position - _target.global_position
		if away.length() > 1.0:
			_owner.face_dir = away.normalized()
			goals.append({"dir": away.normalized(), "weight": 2.0})
	return _steer(goals, _owner.walk_speed * 1.15, delta)

func _wander(delta: float) -> Vector2:
	if brain.idle_wander <= 0.0:
		var pull := _home - _body.global_position
		if pull.length() > brain.leash_radius * 0.5:
			return _steer([{"dir": pull.normalized(), "weight": 1.0}],
				_owner.walk_speed * 0.4, delta)
		return Vector2.ZERO
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.0, 2.5)
		_wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	var goals: Array = [{"dir": _wander_dir, "weight": 1.0}]
	var home_vec := _home - _body.global_position
	if home_vec.length() > 90.0:
		goals.append({"dir": home_vec.normalized(), "weight": 2.0})
	goals += _separation_goals()
	return _steer(goals, _owner.walk_speed * 0.35 * brain.idle_wander, delta)

# ---------------------------------------------------------------- transitions

func _set_state(s: State) -> void:
	state = s
	_state_time = 0.0

func _begin_recover(stunned: bool) -> void:
	_cooldown = _owner.contact_cooldown
	_charge_stunned = stunned
	_recover_override = brain.charge_wall_stun if stunned else 0.0
	_set_state(State.RECOVER)

func _should_flee() -> bool:
	return brain.flee_below_hp > 0.0 and _owner.hp_ratio() <= brain.flee_below_hp

func _release_token() -> void:
	if _has_token:
		CombatDirector.release_token(_owner)
		_has_token = false

# ----------------------------------------------------------------- perception

func _perception(delta: float) -> void:
	_perc_timer -= delta
	if _perc_timer <= 0.0:
		_perc_timer = Tuning.AI_PERCEPTION_INTERVAL
		_update_danger()

	var player: Node2D = _owner.get_player()
	if player == null:
		_visible_now = false
		_lose_awareness(delta)
		return
	_target = player

	var to: Vector2 = player.global_position - _body.global_position
	var dist: float = to.length()
	var dir: Vector2 = to / maxf(dist, 0.001)
	var sensed := false
	if dist <= brain.proximity_radius:
		sensed = _has_los(player.global_position)
	elif dist <= brain.sense_radius:
		var facing: Vector2 = _owner.face_dir
		if facing == Vector2.ZERO:
			facing = Vector2.DOWN
		if absf(facing.angle_to(dir)) <= deg_to_rad(brain.vision_angle * 0.5):
			sensed = _has_los(player.global_position)

	_visible_now = sensed
	if sensed:
		var scale := lerpf(2.0, 0.6, clampf(dist / maxf(brain.sense_radius, 1.0), 0.0, 1.0))
		_awareness = clampf(_awareness + brain.awareness_gain * scale * delta, 0.0, 1.0)
		_last_seen = player.global_position
		if _awareness >= 1.0:
			_has_target = true
			_lose_timer = brain.lose_time
	else:
		_lose_awareness(delta)

func _lose_awareness(delta: float) -> void:
	_awareness = maxf(_awareness - brain.awareness_decay * delta, 0.0)
	if not _has_target:
		return
	_lose_timer -= delta
	var leashed := _body.global_position.distance_to(_home) > brain.leash_radius
	if (_lose_timer <= 0.0 and _awareness <= 0.0) or leashed:
		_drop_target()

func _drop_target() -> void:
	_has_target = false
	_awareness = 0.0
	_release_token()

func _maybe_dodge() -> void:
	if not brain.dodge_player_swing or _dodge_timer > 0.0:
		return
	if not _has_target or not _visible_now or _target == null:
		return
	if state in [State.WINDUP, State.STRIKE, State.RECOVER]:
		return
	if not _target.has_method("is_attacking") or not _target.is_attacking():
		return
	var to_me := _body.global_position - _target.global_position
	var dist := to_me.length()
	if dist > 74.0 or dist < 0.01:
		return
	var pf = _target.get("facing")
	if pf == null or pf == Vector2.ZERO:
		return
	if absf((pf as Vector2).angle_to(to_me.normalized())) > deg_to_rad(60.0):
		return   # the swing isn't aimed our way — no need to bail
	_dodge_dir = Vector2(-to_me.y, to_me.x).normalized() * _strafe_sign
	_dodge_timer = 0.24

func _has_los(target_pos: Vector2) -> bool:
	var space := _body.get_world_2d().direct_space_state
	var ex: Array[RID] = [_body.get_rid()]
	var q := PhysicsRayQueryParameters2D.create(
		_body.global_position, target_pos, Tuning.L_WORLD, ex)
	q.collide_with_areas = false
	return space.intersect_ray(q).is_empty()

# ------------------------------------------------------------ context steering

func _update_danger() -> void:
	var space := _body.get_world_2d().direct_space_state
	var origin := _body.global_position
	var mask := Tuning.L_WORLD
	if brain.avoid_props:
		mask |= Tuning.L_PROP
	var ex: Array[RID] = [_body.get_rid()]
	var raw := PackedFloat32Array()
	raw.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		var q := PhysicsRayQueryParameters2D.create(
			origin, origin + _slots[i] * _look_ahead, mask, ex)
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			raw[i] = 0.0
		else:
			var d: float = origin.distance_to(hit["position"])
			raw[i] = clampf(1.0 - d / _look_ahead, 0.0, 1.0)
	# Bleed into neighbours so the agent gives obstacles a wider berth.
	for i in SLOT_COUNT:
		var prev: float = raw[(i - 1 + SLOT_COUNT) % SLOT_COUNT]
		var nxt: float = raw[(i + 1) % SLOT_COUNT]
		_danger[i] = maxf(raw[i], maxf(prev, nxt) * 0.6)

func _choose_dir(goals: Array) -> Vector2:
	if goals.is_empty():
		return Vector2.ZERO
	var best := -INF
	var best_i := -1
	for i in SLOT_COUNT:
		if _danger[i] >= DANGER_BLOCK:
			continue
		var s := _slots[i]
		var interest := 0.0
		for g in goals:
			interest += g["weight"] * maxf(0.0, s.dot(g["dir"]))
		var score := interest - _danger[i] * DANGER_WEIGHT
		if score > best:
			best = score
			best_i = i
	if best_i == -1:
		# Fully boxed in: pick the least dangerous slot and squeeze out.
		var min_d := INF
		for i in SLOT_COUNT:
			if _danger[i] < min_d:
				min_d = _danger[i]
				best_i = i
	if best_i == -1:
		return Vector2.ZERO
	return _slots[best_i]

func _steer(goals: Array, speed: float, delta: float) -> Vector2:
	var dir := _choose_dir(goals)
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	_heading = _heading.lerp(dir, clampf(TURN_RATE * delta, 0.0, 1.0))
	if _heading.length() < 0.001:
		_heading = dir
	_heading = _heading.normalized()
	return _heading * speed

func _separation_goals() -> Array:
	var here := _body.global_position
	var push := Vector2.ZERO
	for m in _owner.get_tree().get_nodes_in_group("mobs"):
		if m == _owner or not is_instance_valid(m):
			continue
		var d: Vector2 = here - (m as Node2D).global_position
		var dist := d.length()
		if dist > 0.01 and dist < brain.separation_radius:
			push += d / dist * (1.0 - dist / brain.separation_radius)
	if push.length() > 0.001:
		return [{"dir": push.normalized(), "weight": brain.separation_weight}]
	return []

func _pursue(speed: float, delta: float) -> Vector2:
	var to := _seek_pos() - _body.global_position
	if to.length() > 1.0:
		_owner.face_dir = to.normalized()
	var goals: Array = [{"dir": to.normalized(), "weight": 2.0}]
	goals += _separation_goals()
	return _steer(goals, speed, delta)

func _seek_pos() -> Vector2:
	if _visible_now and _target:
		return _target.global_position
	return _last_seen

# ------------------------------------------------------------ visual read-outs

func windup_progress() -> float:
	if state == State.WINDUP:
		return clampf(_state_time / maxf(brain.windup_time, 0.001), 0.0, 1.0)
	return 0.0

func is_charge_stunned() -> bool:
	return _charge_stunned
