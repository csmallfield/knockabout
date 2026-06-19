@tool
class_name SpawnPoint
extends Marker2D
## A named player-arrival position. MapBase collects these into spawn_points on
## load; MapManager places the player at the one whose spawn_id matches the
## arriving door's target_spawn_id. Pure data — carries no content.

@export var spawn_id := "default":
	set(v):
		spawn_id = v
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.4, 0.8, 1.0)
	draw_circle(Vector2.ZERO, 7.0, Color(c.r, c.g, c.b, 0.25))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, c, 2.0)
	draw_line(Vector2.ZERO, Vector2(0.0, -14.0), c, 2.0)
