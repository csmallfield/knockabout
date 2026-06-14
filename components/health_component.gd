class_name HealthComponent
extends Node
## hp + damaged/died signals (GDD §11). Knows nothing about physics.

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

func heal_full() -> void:
	hp = max_hp
	dead = false
