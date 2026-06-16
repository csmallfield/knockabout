class_name HealthComponent
extends Node
## hp + damaged/died signals (GDD §11). Knows nothing about physics — or about
## EventBus. heal() is deliberately pure hp math; the player wraps it to emit
## player_hp_changed (HealthComponent is shared by mobs/props too).

signal damaged(amount: float, event: ImpactEvent)
signal died(event: ImpactEvent)

var max_hp := 10.0
var hp := 10.0
var dead := false

func setup(maximum: float) -> void:
	max_hp = maximum
	hp = maximum
	dead = false

func take_damage(amount: float, event: ImpactEvent = null) -> void:
	if dead or amount <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, event)
	if hp <= 0.0:
		dead = true
		died.emit(event)

## Partial heal, clamped to max_hp (GDD §6.4). No signal — the caller decides
## how to surface it (the player emits player_hp_changed; mobs/props don't).
func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	hp = minf(hp + amount, max_hp)

func heal_full() -> void:
	hp = max_hp
	dead = false
