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
