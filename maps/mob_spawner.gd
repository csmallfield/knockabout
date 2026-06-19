@tool
class_name MobSpawner
extends Node2D
## Spawns mobs on map entry (GDD §7). Mobs are not persisted (D3), so spawners
## re-arm every map load / respawn reset — EXCEPT in a room already cleared this
## run, where they stay silent so the cleared room stays empty on backtrack
## (model B).
##
## Placed in the editor now. count = 1, spread = 0 is "place one enemy exactly
## here"; count > 1, spread > 0 is a scatter cluster. Registers its count with the
## RoomController (group "room_controller") synchronously during _ready — before
## the (deferred) mob nodes exist — so room-clear detection knows the total.

@export var mob_id := "goblin":
	set(v):
		mob_id = v
		queue_redraw()
@export var count := 1:
	set(v):
		count = v
		queue_redraw()
@export var spread := 48.0:
	set(v):
		spread = v
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if WorldState.is_room_cleared(MapManager.current_map_id):
		queue_free()
		return
	var room := get_tree().get_first_node_in_group("room_controller")
	if room:
		room.register_expected(count)
	for i in count:
		var m := Registry.spawn(mob_id)
		if m == null:
			break
		m.position = position + Vector2(
			randf_range(-spread, spread), randf_range(-spread, spread))
		get_parent().add_child.call_deferred(m)
	queue_free()

func _draw() -> void:
	# Editor-only gizmo: a red marker + the scatter radius.
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 8.0, Color(0.9, 0.3, 0.3, 0.7))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 18, Color(1, 0.6, 0.6), 1.5)
	if spread > 0.0:
		draw_arc(Vector2.ZERO, spread, 0.0, TAU, 28, Color(0.9, 0.3, 0.3, 0.35), 1.0)
