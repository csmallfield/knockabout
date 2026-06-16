class_name ImpactEvent
extends RefCounted
## The single currency of the damage system (GDD §5.3).
## body_a / body_b are entity roots implementing the PhysicsEntity duck-type
## (get_stats / get_impact_velocity / apply_impact_result / take_impact_damage),
## or null for a statless static surface (tile walls).

var body_a: Node = null            # instigator / moving party
var body_b: Node = null            # receiver / other party
var normal := Vector2.RIGHT        # from a toward b
var contact_point := Vector2.ZERO
var rel_velocity := Vector2.ZERO   # v_a - v_b at contact
var synthetic := false             # weapon / contact-attack injected event
var synthetic_impulse := 0.0       # mass·px/s applied to receiver along normal
var flat_damage := 0.0             # weapon base damage applied to receiver
var swing_hits := 0                # # distinct enemies this player swing has hit,
                                   # incl. this one. Only the player sets it
                                   # (via resolve_synthetic); 0 everywhere else (§2.6).
var bypass_cooldown := false       # parry reflects: a new attack, not a duplicate
                                   # contact, so skip the pair-cooldown guard (§5.3).
