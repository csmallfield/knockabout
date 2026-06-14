class_name DebrisProfile
extends Resource
## A debris shard class (GDD §8.1). Lifetime stays global (Tuning) — it's a
## perf budget, not content.

@export var mass := 6.0
@export var hp := 5.0
@export var radius := 3.0
@export var color := Color(0.6, 0.55, 0.45)
