class_name MobPuppet
extends Puppet
## A mob's puppet: the hero recoloured (Puppets bakes one per MobProfile), on
## a lite driver: the shared walk and knock layers plus a wind-up / strike
## pose from the brain. Nothing else per frame, so a crowd stays cheap.
##
## LOD: a puppet off screen doesn't pose at all. On screen it poses every
## frame while something fast is happening to it (launched, stunned, dying,
## flashing, winding up or striking). Otherwise it poses every frame in a
## small crowd, and every 2nd or 3rd frame as the crowd grows (walk cycles
## "on twos" or threes), staggered so the work spreads evenly; close to the
## player it drops at most to every 2nd. Skipped time is carried into the
## next pose, so cycles keep their speed.

const NEAR := 140.0           # px from the player: pose at least every 2nd frame
const CROWD_2 := 24           # above this many puppets, idle ones pose every 2nd frame
const CROWD_3 := 60           # ... every 3rd

var mob: MobBase
var _slot := 0
var _acc := 0.0
## Last frame's pose count, for the bench / overlay.
static var posed_this_frame := 0
static var _posed_frame := -1
## Running totals for the bench: poses done and microseconds spent posing.
static var total_poses := 0
static var total_usec := 0
## Bench switch: puppets exist but never pose (isolates their engine cost).
static var frozen := false

func setup_mob(m: MobBase) -> void:
	mob = m
	_slot = randi() % 6
	var id := m.profile.resource_path.get_file().get_basename()
	setup(id, m.radius, m.radius * m.profile.puppet_height, m.walk_speed)
	rig.paper_turn = false

func _process(delta: float) -> void:
	if frozen:
		return
	Puppets.count_me()
	_acc += delta
	var pos := global_position
	if not Puppets.view_rect.has_point(pos):
		return
	if not _urgent():
		var crowd := Puppets.crowd
		var every := 1 if crowd <= CROWD_2 else (2 if crowd <= CROWD_3 else 3)
		if every > 2 and pos.distance_squared_to(Puppets.player_pos) < NEAR * NEAR:
			every = 2
		if (Puppets.frame + _slot) % every != 0:
			return
	if _posed_frame != Puppets.frame:
		_posed_frame = Puppets.frame
		posed_this_frame = 0
	posed_this_frame += 1
	var t0 := Time.get_ticks_usec()
	pose(_acc)
	total_usec += Time.get_ticks_usec() - t0
	total_poses += 1
	_acc = 0.0

func _urgent() -> bool:
	if _dead or _flash > 0.0 or _state != BallisticMotion.State.GROUNDED or _hop > 0.0:
		return true
	if absf(_angle) > 0.01:
		return true
	var st := mob.brain_state()
	return st == MobBrain.State.WINDUP or st == MobBrain.State.STRIKE

func _face_from_velocity() -> bool:
	return false

func _pose_extra(_dt: float) -> void:
	if _dead or _state != BallisticMotion.State.GROUNDED:
		return
	var fx := _side_sign()
	match mob.brain_state():
		MobBrain.State.WINDUP:
			# both arms up and back, lean back: the telegraph
			var w := mob.windup_progress()
			var up := 2.4 * w
			if fx != 0.0:
				rig.add_rot_at(_arm_l_upper, fx * up)
				rig.add_rot_at(_arm_r_upper, fx * up)
				rig.add_rot_at(_torso, -fx * 0.18 * w)
			else:
				rig.add_rot_at(_arm_l_upper, up)
				rig.add_rot_at(_arm_r_upper, -up)
				_sq = lerpf(_sq, -0.08 * w, 0.5)
		MobBrain.State.STRIKE:
			# arms thrown forward, lean in
			if fx != 0.0:
				rig.add_rot_at(_arm_l_upper, -fx * 1.5)
				rig.add_rot_at(_arm_r_upper, -fx * 1.3)
				rig.add_rot_at(_torso, fx * 0.22)
			else:
				rig.add_rot_at(_arm_l_upper, -0.9)
				rig.add_rot_at(_arm_r_upper, 0.9)
				_sq = lerpf(_sq, 0.1, 0.5)
