class_name Puppet
extends Node2D
## The visual body of an actor: a 2D cutout rig (MotionCutoutRig2D, baked by
## the Puppets autoload) plus a blob shadow, driven from the actor's physics.
## Purely visual: the actor's circle collider stays the physics body, so a
## puppet adds no physics cost.
##
## This base holds what the hero and the mobs share:
##   - the walk cycle (legs, arms, bob) from ground speed;
##   - the knock layer, read straight off BallisticMotion: launched bodies
##     hop and tumble with the speed, limbs trail and flail, hard impacts
##     squash, stunned bodies lie tilted and pop back up;
##   - flash, tint and fade (one modulate on the rig; see set_look);
##   - death: topple and fade.
## Subclasses add their own layers in _pose_extra() and decide how often to
## pose (MobPuppet skips frames under its LOD; the hero poses every frame).
##
## Owners write `facing`, `tint`, call set_motion() every physics tick, and
## flash() / squash() / impact() / die() on events.

## Screen-space facing (y down).
var facing := Vector2.DOWN
## Colour multiply and fade (alpha) set by the owner (telegraphs, i-frames).
var tint := Color.WHITE

var rig: MotionCutoutRig2D
var shadow: Sprite2D
var height := 34.0            # screen px, feet to top of the head
var radius := 10.0            # owner's body radius (screen px)

# --- motion inputs (from set_motion) ---
var _state := BallisticMotion.State.GROUNDED
var _vel := Vector2.ZERO
var _walk_ref := 110.0        # owner's walk speed: full stride amplitude

# --- layers' state ---
var _flash := 0.0
var _phase := 0.0
var _gait_amp := 0.0
var _angle := 0.0             # tumble, radians
var _spin := 0.0
var _hop := 0.0               # screen px above the ground
var _hop_v := 0.0
var _sq := 0.0                # squash (+) / stretch (-)
var _sq_v := 0.0
var _trail := Vector2.ZERO    # smoothed velocity the limbs trail
var _lie := 0.0               # tumble resting angle target while down
var _dead := false
var _t := 0.0                 # puppet time (flail noise)
var _seed := 0.0
var _px := 1.0                # baked px per screen px (1 / display_scale)
var _shadow_a := -1.0
var _look_tint := Color(-1, -1, -1)
var _look_flash := -1.0


# Part indices (looked up once; pose by index: no name lookups per frame).
var _leg_l_upper := -1
var _leg_r_upper := -1
var _leg_l_lower := -1
var _leg_r_lower := -1
var _arm_l_upper := -1
var _arm_r_upper := -1
var _arm_l_lower := -1
var _arm_r_lower := -1
var _torso := -1
var _head := -1

const HOP_GRAVITY := 900.0    # screen px/s² for the visual hop
const STRIDE := 26.0          # screen px per full walk cycle (at the hero's size)

func setup(who: String, radius_: float, height_: float, walk_ref: float) -> void:
	radius = radius_
	height = height_
	_walk_ref = maxf(walk_ref, 1.0)
	_seed = randf() * 100.0
	# Feet a little below the collider centre: the circle is the footprint.
	position = Vector2(0.0, radius * 0.55)
	shadow = Puppets.card_sprite(&"shadow", radius * 0.9)
	shadow.scale = Vector2(radius * 2.2 / 92.0, radius * 2.2 / 92.0)
	add_child(shadow)
	rig = Puppets.make_rig(who, height)
	_px = 1.0 / rig.display_scale
	add_child(rig)
	_leg_l_upper = rig.part_id(&"leg_l_upper")
	_leg_r_upper = rig.part_id(&"leg_r_upper")
	_leg_l_lower = rig.part_id(&"leg_l_lower")
	_leg_r_lower = rig.part_id(&"leg_r_lower")
	_arm_l_upper = rig.part_id(&"arm_l_upper")
	_arm_r_upper = rig.part_id(&"arm_r_upper")
	_arm_l_lower = rig.part_id(&"arm_l_lower")
	_arm_r_lower = rig.part_id(&"arm_r_lower")
	_torso = rig.part_id(&"torso")
	_head = rig.part_id(&"head")
	rig.face(facing)

## Every physics tick: the owner's motion state and velocity.
func set_motion(state: int, velocity: Vector2) -> void:
	if state == BallisticMotion.State.BALLISTIC and _state != BallisticMotion.State.BALLISTIC:
		_on_launch(velocity)
	elif state != BallisticMotion.State.BALLISTIC and _state == BallisticMotion.State.BALLISTIC:
		_on_land()
	_state = state
	_vel = velocity

func flash() -> void:
	_flash = 1.0

## A launch or a dash: stretch.
func squash() -> void:
	_sq_v -= 6.0

## A hit that changed the velocity by `dv`: squash along it, kick the spin.
func impact(dv: Vector2) -> void:
	var k := clampf(dv.length() / 600.0, 0.0, 1.0)
	_sq_v += 9.0 * k
	if _state == BallisticMotion.State.BALLISTIC:
		_spin += signf(dv.x if absf(dv.x) > 1.0 else 1.0) * 10.0 * k

func die() -> void:
	_dead = true
	_lie = (PI * 0.5) * (signf(_vel.x) if absf(_vel.x) > 1.0 else (1.0 if randf() < 0.5 else -1.0))

# ------------------------------------------------------------------ posing

## Pose and draw one step of `dt` seconds (may cover skipped frames).
func pose(dt: float) -> void:
	dt = minf(dt, 0.1)
	_t += dt
	_flash = maxf(_flash - dt * 7.0, 0.0)
	var speed := _vel.length()
	var grounded := _state == BallisticMotion.State.GROUNDED and not _dead
	if grounded and speed > 4.0:
		rig.face(_vel if _face_from_velocity() else facing)
	elif grounded:
		rig.face(facing)
	rig.step(dt)
	rig.reset_pose()

	# walk cycle
	var target_amp := clampf(speed / _walk_ref, 0.0, 1.0) if grounded else 0.0
	_gait_amp = lerpf(_gait_amp, target_amp, 1.0 - exp(-dt * 12.0))
	_phase = fposmod(_phase + speed * dt / (STRIDE * height / 34.0) * TAU, TAU) if grounded else _phase
	_walk(_gait_amp)

	# knock layer
	_knock(dt, speed)

	_pose_extra(dt)

	# whole body: tumble about the middle, hop, squash at the feet
	var mid := Vector2(0.0, -height * 0.42 * _px)
	var s := Vector2(1.0 + _sq * 0.6, 1.0 - _sq)
	var bob := -absf(sin(_phase)) * 1.1 * _gait_amp * _px
	var xf := Transform2D(0.0, s, 0.0, Vector2(0.0, bob - _hop * _px))
	if absf(_angle) > 0.001:
		xf = xf * Transform2D(_angle, mid) * Transform2D(0.0, -mid)
	rig.body.transform = xf
	rig.apply()

	var h := clampf(1.0 - _hop / 60.0, 0.4, 1.0) * tint.a
	if h != _shadow_a:
		_shadow_a = h
		shadow.modulate = Color(1, 1, 1, h)
	if tint != _look_tint or _flash != _look_flash:
		_look_tint = tint
		_look_flash = _flash
		rig.set_look(tint, _flash, tint.a)

## Subclasses: extra layers (attack poses, the sword) before the body transform.
func _pose_extra(_dt: float) -> void:
	pass

## Subclasses: face the way they move (true) or keep `facing` (false).
func _face_from_velocity() -> bool:
	return false

## Legs, arms and a little head nod from the gait phase. Side views swing the
## limbs fore and aft; front and back views lift the feet and sway the arms.
func _walk(amp: float) -> void:
	if amp < 0.01:
		return
	var s := sin(_phase)
	var c := cos(_phase)
	var fx := _side_sign()
	if fx != 0.0:
		rig.pose_at(_leg_l_upper, -fx * s * 0.65 * amp)
		rig.pose_at(_leg_r_upper, fx * s * 0.65 * amp)
		rig.pose_at(_leg_l_lower, fx * maxf(0.0, c) * 0.8 * amp)
		rig.pose_at(_leg_r_lower, fx * maxf(0.0, -c) * 0.8 * amp)
		rig.pose_at(_arm_l_upper, fx * s * 0.55 * amp)
		rig.pose_at(_arm_r_upper, -fx * s * 0.55 * amp)
		rig.pose_at(_torso, fx * 0.08 * amp)
	else:
		var lift := 3.5 * _px * amp
		rig.pose_at(_leg_l_upper, 0.0, Vector2(0.0, -maxf(0.0, s) * lift))
		rig.pose_at(_leg_r_upper, 0.0, Vector2(0.0, -maxf(0.0, -s) * lift))
		rig.pose_at(_arm_l_upper, s * 0.25 * amp)
		rig.pose_at(_arm_r_upper, s * 0.25 * amp)
		rig.pose_at(_torso, s * 0.04 * amp)
	rig.pose_at(_head, c * 0.04 * amp, Vector2(0.0, absf(c) * 0.6 * _px * amp))

## +1 when the side view faces right, -1 left, 0 for front and back.
func _side_sign() -> float:
	match rig.view:
		&"side":
			return 1.0
		&"side_left":
			return -1.0
	return 0.0

## The knock layer: hop and tumble while launched, limbs trailing the
## velocity with a flail, squash spring, lying down while stunned or dead.
func _knock(dt: float, speed: float) -> void:
	var ballistic := _state == BallisticMotion.State.BALLISTIC
	# hop (visual only: the actor slides on the ground plane)
	if ballistic or _hop > 0.0:
		_hop_v -= HOP_GRAVITY * dt
		_hop += _hop_v * dt
		if _hop <= 0.0:
			_hop = 0.0
			if _hop_v < -120.0 and ballistic:
				_hop_v = -_hop_v * 0.35           # a skip off the ground
				_sq_v += 4.0
			else:
				_hop_v = 0.0
	# tumble
	if ballistic:
		_spin *= exp(-dt * 1.2)
		_angle += _spin * dt
	else:
		var want := _lie if (_dead or _state == BallisticMotion.State.STUNNED) else 0.0
		if _state == BallisticMotion.State.GROUNDED and not _dead:
			want = 0.0
		var d := wrapf(want - _angle, -PI, PI)
		_spin = lerpf(_spin, d * 14.0, 1.0 - exp(-dt * 18.0))
		_angle += _spin * dt
		if absf(_angle) > TAU:
			_angle = wrapf(_angle, -PI, PI)
	# squash spring
	_sq_v += (-260.0 * _sq - 14.0 * _sq_v) * dt
	_sq = clampf(_sq + _sq_v * dt, -0.35, 0.4)
	# limbs trail the velocity and flail with speed
	_trail = _trail.lerp(_vel, 1.0 - exp(-dt * 10.0))
	var k := clampf(_trail.length() / 500.0, 0.0, 1.0) if (ballistic or _dead) else 0.0
	if k > 0.01:
		var tx := -clampf(_trail.x / 400.0, -1.0, 1.0)
		var f1 := sin(_t * 23.0 + _seed) * 0.6
		var f2 := sin(_t * 19.0 + _seed * 1.7) * 0.6
		rig.add_rot_at(_arm_l_upper, (tx * 1.4 + f1 - 1.2) * k)
		rig.add_rot_at(_arm_r_upper, (tx * 1.4 - f2 + 1.2) * k)
		rig.add_rot_at(_arm_l_lower, f2 * 0.8 * k)
		rig.add_rot_at(_arm_r_lower, -f1 * 0.8 * k)
		rig.add_rot_at(_leg_l_upper, (tx * 0.7 + f2 * 0.7) * k)
		rig.add_rot_at(_leg_r_upper, (tx * 0.7 - f1 * 0.7) * k)
		rig.add_rot_at(_head, tx * 0.35 * k)
	if _state == BallisticMotion.State.STUNNED and not _dead:
		rig.add_rot_at(_head, sin(_t * 9.0) * 0.18)       # dizzy

func _on_launch(v: Vector2) -> void:
	var s := v.length()
	_hop_v = clampf(s * 0.45, 80.0, 380.0)
	_spin = signf(v.x if absf(v.x) > 1.0 else 1.0) * clampf(s / 45.0, 3.0, 22.0)
	_sq_v -= 7.0
	_lie = (PI * 0.5) * signf(_spin) if s > 500.0 else 0.0

func _on_land() -> void:
	_sq_v += 6.0
