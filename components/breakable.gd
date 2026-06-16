class_name Breakable
extends Node
## death → debris burst + destroyed variant + WorldState check-in (GDD §8.2).
## Attach to an entity root that has `stats`, optional `persist_id`,
## and lives inside a map's Entities node.

var _root: Node2D
var _stats: PhysicsStats

func setup(root: Node2D, stats: PhysicsStats, health: HealthComponent) -> void:
	_root = root
	_stats = stats
	health.died.connect(_on_died)

func _on_died(event: ImpactEvent) -> void:
	var pos := _root.global_position
	var contact: Vector2 = event.contact_point if event else pos
	var incoming := Vector2.ZERO
	if event:
		# Velocity of whatever slammed into us, projected sensibly.
		incoming = event.rel_velocity if _root == event.body_b else -event.rel_velocity

	if _stats.break_payload:
		DebrisPool.spawn_burst(contact if contact != Vector2.ZERO else pos,
			incoming, _stats.break_payload)

	var parent := _root.get_parent()
	if _stats.destroyed_variant and parent:
		var variant := _stats.destroyed_variant.instantiate()
		variant.position = _root.position
		parent.add_child(variant)

	var persist_id: String = _root.get("persist_id") if _root.get("persist_id") != null else ""
	if persist_id != "":
		WorldState.mark_destroyed(MapManager.current_map_id, persist_id)

	EventBus.entity_died.emit(_root, _stats, MapManager.current_map_id)

	# Let the entity run its own teardown (e.g. a mob's gray-out + fade corpse).
	# Anything without that hook (props) is removed immediately, as before.
	if _root.has_method("begin_death_sequence"):
		_root.begin_death_sequence(event)
	else:
		_root.queue_free()
