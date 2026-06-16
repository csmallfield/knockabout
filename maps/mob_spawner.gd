class_name MobSpawner
extends Node2D
## Spawns mobs on map entry (GDD §7). Mobs are not persisted (D3), so spawners
## naturally re-arm every map load / respawn reset — EXCEPT in a room that has
## already been cleared this run, where they stay silent so the cleared room
## stays empty on backtrack (model B). MapBase.add_mob_spawner also guards this,
## so this is belt-and-braces for spawners placed directly.

@export var mob_id := "goblin"
@export var count := 1
@export var spread := 48.0

func _ready() -> void:
	if WorldState.is_room_cleared(MapManager.current_map_id):
		queue_free()
		return
	for i in count:
		var m := Registry.spawn(mob_id)
		if m == null:
			break
		m.position = position + Vector2(
			randf_range(-spread, spread), randf_range(-spread, spread))
		get_parent().add_child.call_deferred(m)
	queue_free()
