class_name MobProfile
extends Resource
## One mob archetype = one file. The generic mob scene builds itself from this.

@export var stats: PhysicsStats

@export_group("Brain")
@export var brain: BrainProfile
@export var walk_speed := 110.0
@export var aggro_radius := 280.0

@export_group("Contact attack")
@export var contact_damage := 6.0
@export var contact_impulse := 6000.0
@export var contact_cooldown := 0.8

@export_group("Body")
@export var radius := 10.0
@export var color := Color(0.35, 0.8, 0.3)

@export_group("Rewards")
@export var point_value := 10.0   ## > 0 ⇒ pays score on death (props leave it 0)
@export var loot: LootTable       ## null ⇒ no drops
