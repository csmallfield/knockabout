class_name MobSpawner
extends Node2D
## Spawns mobs on map entry (GDD §7). Mobs are not persisted (D3), so
## spawners naturally re-arm every map load / respawn reset.

@export var mob_id := "goblin"
@export var count := 1
@export var spread := 48.0

func _ready() -> void:
	for i in count:
		var m := Registry.spawn(mob_id)
		if m == null:
			break
		m.position = position + Vector2(
			randf_range(-spread, spread), randf_range(-spread, spread))
		get_parent().add_child.call_deferred(m)
	queue_free()
