class_name ScoringConfig
extends Resource
## Global scoring rules as data (GDD §2.1). ScoreManager loads one instance at
## boot. Even the scoring *rules* live here so they iterate without code edits.

@export_group("Power meter — fill")
@export var base_fill_cost := 100.0     ## meter points to clear level 0→1
@export var fill_cost_growth := 1.7     ## ×per level; >1 ⇒ exponentially harder
@export var per_hit_meter := 10.0       ## base meter gain per landed hit
@export var damage_meter_factor := 0.4  ## + this × impact damage (decision 3A)
@export var multi_hit_mult := 1.5       ## ≥2 enemies in one swing (per hit)
@export var bounce_mult := 2.0          ## indirect / enemy-into-enemy hit

@export_group("Power meter — decay & reset")
@export var combo_grace := 2.5          ## s of no-hit before the meter decays
@export var meter_decay_rate := 60.0    ## meter points/s once decaying
## On level-down from decay, meter refills to (cost of new level − overflow).
## On player damage: full reset to ×1, empty bar (decision 6A) — hardcoded.

@export_group("Scoring")
@export var indirect_needs_combo := true  ## only score indirect hits while a combo is live
