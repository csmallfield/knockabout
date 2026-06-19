class_name MapBase
extends Node2D
## Map scene template. A room is now a hand-authored .tscn:
##   Room (this; map_id + is_final set in the inspector)
##   ├── Ground         TileMapLayer, no collision        ← painted terrain
##   ├── Walls          TileMapLayer, L_WORLD collision    ← painted shell + per-tile restitution
##   ├── Entities       Node2D (y_sort_enabled)            ← prop/spawner instances; player reparented here
##   ├── Exits          Node2D                             ← Gate instances
##   ├── SpawnPoints    Node2D                             ← SpawnPoint markers
##   └── RoomController Node                               ← gates/spawners self-register with it
##
## MapBase no longer builds geometry. It collects the authored nodes, exposes the
## three things MapManager reads (spawn_points, bounds, entities), and finalizes
## the room-clear loop. Gates and MobSpawners self-register with the
## RoomController during their own _ready (children ready before the parent), so
## by the time this _ready runs the controller already knows its gate set and
## expected kill count.

@export var map_id := ""
@export var is_final := false       ## clearing this room ends the run (the leaf)

var bounds := Rect2()
var spawn_points := {}              ## { spawn_id: Vector2 (global px) }, from SpawnPoint nodes
var entities: Node2D                ## authored, y-sorted; the player is reparented here

var _room: RoomController

func _ready() -> void:
	entities = get_node_or_null("Entities")
	if entities == null:
		push_error("%s: missing 'Entities' node — creating a fallback." % name)
		entities = Node2D.new()
		entities.name = "Entities"
		entities.y_sort_enabled = true
		add_child(entities)

	_room = _resolve_room()
	_collect_spawn_points()
	_compute_bounds()

	_room.is_final = is_final
	_room.finalize(_effective_map_id())

## Debug failsafe (dev.gd F10): force this room open.
func force_clear_room() -> void:
	if _room:
		_room.force_clear()

# ------------------------------------------------------------------- internals

func _resolve_room() -> RoomController:
	var r := get_node_or_null("RoomController") as RoomController
	if r == null:
		# Misauthored room: don't crash, but it will be INERT (no gating) because
		# children couldn't find a controller to register with during their
		# _ready. Author a RoomController node in the room scene.
		push_warning("%s: no authored RoomController — room will not gate." % name)
		r = RoomController.new()
		r.name = "RoomController"
		add_child(r)
	return r

func _collect_spawn_points() -> void:
	for sp in find_children("*", "SpawnPoint", true, false):
		spawn_points[(sp as SpawnPoint).spawn_id] = (sp as Node2D).global_position

func _compute_bounds() -> void:
	# Camera limits = the ground footprint in pixels. A non-rectangular room gets
	# its bounding box, which is the correct behaviour for camera clamping.
	var ground := get_node_or_null("Ground") as TileMapLayer
	var r := ground.get_used_rect() if ground else Rect2i()
	bounds = Rect2(Vector2(r.position) * Tuning.TILE, Vector2(r.size) * Tuning.TILE)

func _effective_map_id() -> String:
	return MapManager.current_map_id if MapManager.current_map_id != "" else map_id
