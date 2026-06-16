class_name BuffComponent
extends Node
## Timed player buffs (GDD §6.5). Composition over flags, matching the codebase
## style (BallisticMotion, HealthComponent). Holds active buffs keyed by kind;
## ticks them down each physics frame. The player *queries* this every tick —
## the component never touches the body, deals damage, or moves anything.

# kind (LootProfile.Kind) -> { "time_left": float, "payload": Dictionary }
var _active := {}

## Push or refresh a buff. Refresh-longest: a fresh pickup never *shortens* an
## existing buff of the same kind, only extends it.
func apply(kind: int, duration: float, payload: Dictionary = {}) -> void:
	var existing: Dictionary = _active.get(kind, {})
	var remaining: float = existing.get("time_left", 0.0)
	_active[kind] = {
		"time_left": maxf(duration, remaining),
		"payload": payload if not payload.is_empty() else existing.get("payload", {}),
	}

func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	# keys() returns a copy, so erasing mid-iteration is safe.
	for kind in _active.keys():
		_active[kind]["time_left"] -= delta
		if _active[kind]["time_left"] <= 0.0:
			_active.erase(kind)

func is_active(kind: int) -> bool:
	return _active.has(kind)

func time_left(kind: int) -> float:
	return _active.get(kind, {}).get("time_left", 0.0)

func payload(kind: int) -> Dictionary:
	return _active.get(kind, {}).get("payload", {})

## Convenience: the SPEED scalar, or 1.0 when no SPEED buff is live.
func speed_mult() -> float:
	if not _active.has(LootProfile.Kind.SPEED):
		return 1.0
	return _active[LootProfile.Kind.SPEED]["payload"].get("speed_mult", 1.0)
