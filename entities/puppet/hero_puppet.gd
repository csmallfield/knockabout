class_name HeroPuppet
extends Puppet
## The player's puppet: the full layer stack every frame, plus
##   - the sword arm on IK, its hand riding the actual swing arc (the club
##     pivot's angle, which is also the hitbox): what you see is what hits;
##   - the sword arm and blade drawn in front of the body when the arc is
##     toward the camera, behind it when it's away;
##   - the charge wind-up (the pivot cocks back), the block (free arm up
##     toward the facing, a crouch), the roll (a full spin), a paper turn.

var player: Player
var _roll_angle := 0.0
var _arm_depth := 0

func setup_hero(p: Player) -> void:
	player = p
	setup("hero", p.profile.body_radius, p.profile.body_radius * Puppets.hero_height_per_radius, p.profile.walk_speed)
	rig.add_prop(&"sword", &"hand_r", &"sword", Vector2(0.0, 1.0 * _px), 0.0, false)
	rig.paper_turn = true
	# A ground ring under the feet: in a crowd of recoloured copies the hero
	# must read at a glance. Drawn first, under the shadow and the rig.
	var ring := Puppets.card_sprite(&"marker", 1.0)
	ring.scale = Vector2.ONE * (radius * 2.6 / 92.0)
	add_child(ring)
	move_child(ring, 0)

func _process(delta: float) -> void:
	pose(delta)

func _pose_extra(dt: float) -> void:
	var swinging := player.is_attacking()
	var charging := player.is_charging()
	var blocking := player.is_blocking()
	var shoulder := rig.part_point(&"arm_r_upper")
	var reach := _arm_length() * 0.94

	# Sword arm: on the swing arc while swinging or charging, else at rest.
	var depth := 0
	if (swinging or charging) and _state == BallisticMotion.State.GROUNDED:
		var dir := Vector2.from_angle(player.weapon_angle())
		var local := Vector2(dir.x * (-1.0 if rig.mirrored else 1.0), dir.y)
		var target := shoulder + local * reach
		rig.solve_limb(&"arm_r_upper", &"arm_r_lower", &"hand_r", target, _elbow_bend(local))
		_point_sword(local)
		depth = 1 if local.y > -0.25 else -1
	else:
		_rest_sword()
	if depth != _arm_depth:
		_arm_depth = depth
		rig.depth(&"arm_r_upper", depth)

	# Block: free arm up toward the facing, a small crouch.
	if blocking and _state == BallisticMotion.State.GROUNDED:
		var f := Vector2(facing.x * (-1.0 if rig.mirrored else 1.0), facing.y)
		var target := rig.part_point(&"arm_l_upper") + (f * 0.8 + Vector2(0.0, -0.35)).normalized() * _arm_length(&"arm_l_upper", &"arm_l_lower", &"hand_l") * 0.8
		rig.solve_limb(&"arm_l_upper", &"arm_l_lower", &"hand_l", target, -_elbow_bend(f))
		_sq = lerpf(_sq, 0.08, 1.0 - exp(-dt * 20.0))

	# Charge: lean into it.
	if charging:
		rig.add_rot(&"torso", -_side_sign() * 0.12 * player.charge_ratio())

	# Roll: one full turn about the middle over the roll.
	var rt := player.roll_progress()
	if rt >= 0.0:
		var dirx := signf(facing.x) if absf(facing.x) > 0.2 else 1.0
		_roll_angle = dirx * TAU * rt
		_angle = _roll_angle
		_spin = 0.0
	elif _roll_angle != 0.0:
		_roll_angle = 0.0
		_angle = 0.0

func _face_from_velocity() -> bool:
	return false          # the player aims with the stick: always face `facing`

func _arm_length(u := &"arm_r_upper", l := &"arm_r_lower", h := &"hand_r") -> float:
	return rig.rest_pivot(u).distance_to(rig.rest_pivot(l)) + rig.rest_pivot(l).distance_to(rig.rest_pivot(h))

## Which way the elbow bends for a reach toward `dir`: down and out.
func _elbow_bend(dir: Vector2) -> float:
	return -1.0 if dir.x >= 0.0 else 1.0

## Turn the blade so its tip points along `dir` (rig-local).
func _point_sword(dir: Vector2) -> void:
	var hand_rot := rig.part_transform(&"hand_r").get_rotation()
	rig.pose(&"sword", wrapf(dir.angle() + PI * 0.5 - hand_rot, -PI, PI))

## At rest: the blade tilted up and forward, as in Cutout Isle.
func _rest_sword() -> void:
	var fx := _side_sign()
	var tilt := -0.6 if fx == 0.0 else -0.9 * fx
	if rig.view == &"back":
		tilt = 0.6
	rig.pose(&"sword", tilt)
