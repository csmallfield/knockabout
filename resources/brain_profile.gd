class_name BrainProfile
extends Resource
## Per-archetype AI personality, one file per mob (mirrors the PhysicsStats
## embedding pattern). MobBrain reads ONLY this — "smarter mob" = new .tres.
## Physics-law constants (perception interval, attacker cap) stay in Tuning;
## everything here is content you tune per-thing.

enum AttackStyle {
	CONTACT,   ## step in and touch (the old behaviour, but telegraphed)
	LUNGE,     ## short committed dash on the locked aim direction
	CHARGE,    ## long telegraphed dash; self-stuns if it slams a wall
}

@export_group("Perception")
@export var sense_radius := 280.0        ## cone sight range
@export var proximity_radius := 90.0     ## 360° close sense (still needs LOS)
@export var vision_angle := 140.0        ## full cone angle (deg) for distant sight
@export var awareness_gain := 2.5        ## /s fill while the player is visible
@export var awareness_decay := 1.0       ## /s drain while not visible
@export var lose_time := 3.0             ## s of no-LOS before giving up the chase
@export var leash_radius := 600.0        ## px from spawn before a forced disengage

@export_group("Engagement")
@export var engage_distance := 34.0      ## preferred standoff (center-to-center)
@export var engage_tolerance := 16.0     ## dead-band around the standoff ring
@export var strafe_speed_factor := 0.7   ## of walk_speed while circling
@export_range(0.0, 1.0) var aggression := 0.5  ## bias toward attacking vs holding

@export_group("Attack")
@export var attack_style: AttackStyle = AttackStyle.CONTACT
@export var windup_time := 0.35          ## telegraph length before the strike
@export var recover_time := 0.5          ## post-strike back-off before re-engaging
@export var dash_speed := 320.0          ## LUNGE / CHARGE dash velocity
@export var dash_time := 0.28            ## LUNGE / CHARGE dash duration
@export var charge_wall_stun := 1.2      ## s dazed if a CHARGE rams a wall

@export_group("Reactions")
@export var dodge_player_swing := false  ## skitter sideways when the player swings
@export var dodge_speed := 360.0
@export_range(0.0, 1.0) var flee_below_hp := 0.0  ## 0 = never flee

@export_group("Steering")
@export var separation_radius := 34.0    ## boid spacing radius from other mobs
@export var separation_weight := 1.4
@export var avoid_props := true           ## also steer around loose props, not just walls
@export_range(0.0, 1.0) var idle_wander := 0.15  ## ambient drift when unaware (0 = statue)
