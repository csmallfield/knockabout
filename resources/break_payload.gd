class_name BreakPayload
extends Resource
## Debris specification for breakables (GDD §8.2). Shards come from DebrisPool.

@export var debris: DebrisProfile
@export var count_min := 3
@export var count_max := 6
@export var eject_speed_min := 150.0
@export var eject_speed_max := 350.0
@export var inherit_factor := 0.5   # × incoming velocity added to every shard
