class_name PhysicsStats
extends Resource
## The uniform stat block every physical thing carries (GDD §5.1, pillar 1).

@export var mass := 100.0          # knockback response / projectile damage potential
@export var max_hp := 100.0
@export var toughness := 0.0       # per-impact damage floor (≤ ⇒ ignored entirely)
@export var launch_speed := 250.0  # post-impact speed above this ⇒ actor goes BALLISTIC
@export_range(0.0, 1.0) var restitution := 0.5
@export var drag := 2.0            # ballistic decay /s; also linear_damp for props
@export var breakable := false
@export var break_payload: BreakPayload
@export var destroyed_variant: PackedScene   # optional remnant (tree → stump)
