class_name LootProfile
extends Resource
## One pickup type = one file (consistent with every other entity, GDD §2.4).
## Configures the pooled Pickup and its collect payload.

enum Kind { COIN, HEALTH, POWER, SPEED, INVINCIBLE }

@export var kind: Kind = Kind.COIN
@export var color := Color.WHITE
@export var radius := 6.0
@export var magnetize_radius := 48.0   ## drifts to player within this range
@export var lifetime := 12.0           ## despawn if uncollected (0 = forever)

@export_group("Payload")
@export var amount := 1.0     ## COIN: count · HEALTH: hp · SPEED/INVINCIBLE: seconds
@export var power_levels := 1 ## POWER: levels added (decision 7A — bar carried)
@export var speed_mult := 1.4 ## SPEED: scalar on move speed (+ attack pace)
