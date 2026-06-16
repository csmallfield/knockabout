class_name MapBase
extends Node2D
## Map scene template (GDD §9.1). Ground/Walls TileMapLayers + y-sorted
## Entities. Tiles and layouts are authored in code for the prototype
## (deviation from painted tilemaps — see README); the structure matches
## the GDD so painted maps can replace these later without system changes.
##
## ROOM LOOP: each map owns a RoomController. Doors authored with add_gate() are
## locked on entry and open when the room's mobs (declared via add_mob_spawner)
## are all defeated. A cleared room persists in WorldState; on re-entry its
## spawners stay silent and its gates start open (backtracking model B). Set
## is_final = true on the last room — clearing it wins the run.

const T := 32

static var _tileset: TileSet

@export var map_id := ""
@export var is_final := false       ## clearing this room ends the run (the leaf)
var bounds := Rect2()
var size_tiles := Vector2i(30, 17)

var ground: TileMapLayer
var walls: TileMapLayer
var entities: Node2D
var exits: Node2D
var spawn_points := {}   # { spawn_id: Vector2 (global px) }

var _room: RoomController

func _ready() -> void:
	ground = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = _get_tileset()
	add_child(ground)

	walls = TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = _get_tileset()
	add_child(walls)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	exits = Node2D.new()
	exits.name = "Exits"
	add_child(exits)

	_room = RoomController.new()
	_room.name = "RoomController"
	add_child(_room)

	_build()

	# is_final is read AFTER _build, so a room can set it in script (the robust
	# source of truth) rather than depending on the scene file carrying it.
	# Mob counts were registered synchronously in _build, so finalize is safe
	# even though the mobs themselves spawn deferred.
	_room.is_final = is_final
	_room.finalize(MapManager.current_map_id if MapManager.current_map_id != "" else map_id)

## Override in concrete maps.
func _build() -> void:
	pass

## Debug failsafe (dev.gd): force this room open (e.g. if a mob is unreachable).
func force_clear_room() -> void:
	if _room:
		_room.force_clear()

# ------------------------------------------------------------------- helpers

func fill_ground(tiles: Vector2i) -> void:
	size_tiles = tiles
	bounds = Rect2(Vector2.ZERO, Vector2(tiles) * T)
	for y in tiles.y:
		for x in tiles.x:
			ground.set_cell(Vector2i(x, y), 0, Vector2i(randi_range(0, 1), 0))

func border_walls() -> void:
	for x in size_tiles.x:
		wall_cell(Vector2i(x, 0))
		wall_cell(Vector2i(x, size_tiles.y - 1))
	for y in size_tiles.y:
		wall_cell(Vector2i(0, y))
		wall_cell(Vector2i(size_tiles.x - 1, y))

func wall_cell(cell: Vector2i) -> void:
	walls.set_cell(cell, 0, Vector2i(2, 0))

func clear_wall(cell: Vector2i) -> void:
	walls.erase_cell(cell)

func add_spawn(spawn_id: String, tile: Vector2) -> void:
	spawn_points[spawn_id] = tile * T + Vector2(T, T) * 0.5

func place(id: String, tile: Vector2, persist_id := "") -> Node:
	var profile := Registry.get_profile(id)
	if profile == null:
		return null
	if persist_id != "" and WorldState.is_destroyed(map_id, persist_id):
		# Already destroyed this session: skip instancing entirely unless a
		# destroyed variant must still appear (entity self-resolves in _ready).
		var stats: PhysicsStats = profile.get("stats")
		if stats == null or stats.destroyed_variant == null:
			return null
	var n := Registry.spawn(id)
	if n == null:
		return null
	if persist_id != "":
		n.set("persist_id", persist_id)
	n.position = tile * T + Vector2(T, T) * 0.5
	entities.add_child(n)
	return n

## A lockable, room-gated door. tile_rect is the doorway footprint (in tiles).
## Registered with the RoomController so it locks/opens with the room.
func add_gate(tile_rect: Rect2, target_map: String, target_spawn: String) -> Gate:
	var g := Gate.new()
	g.target_map_id = target_map
	g.target_spawn_id = target_spawn
	g.position = tile_rect.position * T + tile_rect.size * T * 0.5
	g.size_px = tile_rect.size * T
	exits.add_child(g)
	if _room:
		_room.register_gate(g)
	return g

## Carve a doorway in the border wall on a given side and drop a gated door in
## it, plus a spawn point just inside (where the player lands when arriving
## through this door from the neighbouring room).
##   side  : "N" / "S" / "W" / "E"
##   along : start tile along that edge (x for N/S, y for W/E)
##   length: gap width in tiles (2 is a comfortable doorway)
##   target_map / target_spawn : where this door leads
##   spawn_id  : the local spawn the *neighbour* aims at to arrive here
func add_door(side: String, along: int, length: int, target_map: String,
		target_spawn: String, spawn_id: String, inset := 2) -> void:
	var w := size_tiles.x
	var h := size_tiles.y
	var rect := Rect2()
	var spawn_tile := Vector2.ZERO
	var mid := along + length * 0.5 - 0.5
	match side:
		"N":
			for i in length: clear_wall(Vector2i(along + i, 0))
			rect = Rect2(Vector2(along, 0), Vector2(length, 1))
			spawn_tile = Vector2(mid, inset)
		"S":
			for i in length: clear_wall(Vector2i(along + i, h - 1))
			rect = Rect2(Vector2(along, h - 1), Vector2(length, 1))
			spawn_tile = Vector2(mid, h - 1 - inset)
		"W":
			for i in length: clear_wall(Vector2i(0, along + i))
			rect = Rect2(Vector2(0, along), Vector2(1, length))
			spawn_tile = Vector2(inset, mid)
		"E":
			for i in length: clear_wall(Vector2i(w - 1, along + i))
			rect = Rect2(Vector2(w - 1, along), Vector2(1, length))
			spawn_tile = Vector2(w - 1 - inset, mid)
		_:
			push_error("add_door: bad side '%s'" % side)
			return
	add_gate(rect, target_map, target_spawn)
	add_spawn(spawn_id, spawn_tile)

## A mob spawner that respects room-clear persistence. On a cleared room it is
## skipped entirely (no respawns on backtrack); otherwise its count is declared
## to the RoomController so the room knows how many kills equal "cleared".
func add_mob_spawner(id: String, tile: Vector2, count := 1, spread := 48.0) -> void:
	if WorldState.is_room_cleared(MapManager.current_map_id):
		return
	if _room:
		_room.register_expected(count)
	var s := MobSpawner.new()
	s.mob_id = id
	s.count = count
	s.spread = spread
	s.position = tile * T + Vector2(T, T) * 0.5
	entities.add_child(s)

## Legacy unlocked exit (used by the original prototype maps). Always passable;
## not registered with the RoomController. Prefer add_gate for run rooms.
func add_exit(tile_rect: Rect2, target_map: String, target_spawn: String,
		auto := true) -> ExitArea:
	var e := ExitArea.new()
	e.target_map_id = target_map
	e.target_spawn_id = target_spawn
	e.auto_trigger = auto
	e.position = tile_rect.position * T + tile_rect.size * T * 0.5
	e.size_px = tile_rect.size * T
	exits.add_child(e)
	return e

## A building footprint of modular wall segments + roof + interact door (§8.3).
func add_building(tile_rect: Rect2i, door_tile: Vector2i, interior_map: String,
		wall_id: String, id_prefix: String) -> void:
	var idx := 0
	for x in range(tile_rect.position.x, tile_rect.end.x):
		for y in range(tile_rect.position.y, tile_rect.end.y):
			var on_edge: bool = x == tile_rect.position.x or x == tile_rect.end.x - 1 \
				or y == tile_rect.position.y or y == tile_rect.end.y - 1
			if not on_edge or Vector2i(x, y) == door_tile:
				continue
			place(wall_id, Vector2(x, y), "%s_wall_%d" % [id_prefix, idx])
			idx += 1
	# Roof: hides the footprint; fades when the player is underneath.
	var roof := BuildingRoof.new()
	roof.position = Vector2(tile_rect.position) * T
	roof.size_px = Vector2(tile_rect.size) * T
	add_child(roof)
	# Door → interior (interact-triggered, §8.3).
	add_exit(Rect2(Vector2(door_tile), Vector2.ONE), interior_map, "default", false)

## A solid decorative wall block of segments (no door). Handy for carving up a
## room into chambers/cover without a full building. Segments are destructible
## props like any other wall_segment.
func add_wall_run(cells: Array, wall_id: String, id_prefix: String) -> void:
	var idx := 0
	for c in cells:
		place(wall_id, c, "%s_block_%d" % [id_prefix, idx])
		idx += 1

# ------------------------------------------------------------ runtime tileset

static func _get_tileset() -> TileSet:
	if _tileset:
		return _tileset
	var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 32, 32), Color(0.32, 0.46, 0.27))    # ground A
	img.fill_rect(Rect2i(32, 0, 32, 32), Color(0.30, 0.43, 0.25))   # ground B
	img.fill_rect(Rect2i(64, 0, 32, 32), Color(0.25, 0.24, 0.28))   # wall
	img.fill_rect(Rect2i(66, 2, 28, 28), Color(0.33, 0.32, 0.37))
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Tuning.L_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(32, 32)
	ts.add_source(src, 0)
	for i in 3:
		src.create_tile(Vector2i(i, 0))
	var wall_data := src.get_tile_data(Vector2i(2, 0), 0)
	wall_data.add_collision_polygon(0)
	wall_data.set_collision_polygon_points(0, 0, PackedVector2Array(
		[Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	_tileset = ts
	return ts
