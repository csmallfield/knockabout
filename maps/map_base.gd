class_name MapBase
extends Node2D
## Map scene template (GDD §9.1). Ground/Walls TileMapLayers + y-sorted
## Entities. Tiles and layouts are authored in code for the prototype
## (deviation from painted tilemaps — see README); the structure matches
## the GDD so painted maps can replace these later without system changes.

const T := 32

static var _tileset: TileSet

@export var map_id := ""
var bounds := Rect2()
var size_tiles := Vector2i(30, 17)

var ground: TileMapLayer
var walls: TileMapLayer
var entities: Node2D
var exits: Node2D
var spawn_points := {}   # { spawn_id: Vector2 (global px) }

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

	_build()

## Override in concrete maps.
func _build() -> void:
	pass

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
