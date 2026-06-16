class_name PlayerProfile
extends Resource
## Everything that defines the player character's feel, in one file.

@export var stats: PhysicsStats
@export var weapon: WeaponProfile

@export_group("Movement")
@export var walk_speed := 150.0
@export var roll_speed := 420.0
@export var roll_duration := 0.35
@export var roll_cooldown := 0.8
@export var roll_iframes := 0.25
@export var hit_iframes := 0.6      # post-hit damage immunity (knockback still applies)

@export_group("Body")
@export var body_radius := 10.0
@export var color := Color(0.95, 0.85, 0.35)

@export_group("Buffs")
@export var speed_attack_scaling := true   ## SPEED also shortens attack cooldown (§6.5)
## INVINCIBLE blocks damage AND knockback (decision 8A) — hardcoded in Player.

@export_group("Charge")
@export var charge_base_move_mult := 0.6   ## move speed while winding up below tier 1

@export_group("Block")
@export var block_damage_mult := 0.25      ## incoming damage kept while blocking
@export var block_knockback_mult := 0.3    ## incoming knockback kept while blocking
@export var block_move_mult := 0.5         ## move speed while blocking
@export var block_arc_degrees := 150.0     ## frontal cone that can block (360 = omni)

@export_group("Parry")
@export var parry_window := 0.16                ## s after pressing block that counts as a parry
@export var parry_reflect_damage_mult := 1.5    ## × the damage that would have hit you
@export var parry_reflect_impulse_mult := 1.2   ## × the attack's own impulse (synthetic hits)
@export var parry_reflect_impulse := 30000.0    ## fallback impulse for non-synthetic parries
