@tool
extends EditorScript
## OPTIONAL bootstrap. Generates a VALID res://maps/room_01.tscn you can then open
## and edit visually. This exists only because a TileMapLayer's painted cells are
## a binary blob that can't be hand-written — running this through Godot's API
## produces correct tile data. Once you have room_01, author rooms 02–10 by hand
## in the editor; you can delete this tool.
##
## RUN IT: AFTER build_tileset.gd. Open this file, File > Run (Ctrl+Shift+X).
##
## Reproduces the old room_01 layout (18×12, two goblins, E + S doors, a little
## cover) as authored nodes + painted tiles. For the vertical slice both gates
## loop back to room_01, so MapManager.MAPS only needs room_01.

const TILESET := "res://maps/knockabout_tileset.tres"
const OUT := "res://maps/room_01.tscn"
const TILE := 32
const SIZE := Vector2i(18, 12)

const GROUND_A := Vector2i(0, 0)
const GROUND_B := Vector2i(1, 0)
const WALL := Vector2i(2, 0)          # neutral wall (restitution 0.5)

# Door gaps (unpainted wall cells). Edit freely.
const DOOR_E := [5, 6]                # rows on the east edge (x = SIZE.x-1)
const DOOR_S := [8, 9]                # cols on the south edge (y = SIZE.y-1)

var _root: Node2D

func _run() -> void:
	var ts := load(TILESET) as TileSet
	if ts == null:
		push_error("Run build_tileset.gd first — %s is missing." % TILESET)
		return

	_root = Node2D.new()
	_root.name = "Room01"
	_root.set_script(load("res://maps/map_base.gd"))
	_root.set("map_id", "room_01")
	_root.set("is_final", false)

	_build_ground(ts)
	_build_walls(ts)
	_build_room_controller()
	var entities := _build_entities()
	var exits := _build_exits()
	var spawns := _build_spawnpoints()

	# --- props (free position, including sub-tile offsets) ---
	_add_prop(entities, "res://entities/props/barrel.tscn", Vector2(6, 3))
	_add_prop(entities, "res://entities/props/barrel.tscn", Vector2(7, 3.5))
	_add_prop(entities, "res://entities/props/tree.tscn", Vector2(12, 8))
	_add_prop(entities, "res://entities/props/rock.tscn", Vector2(5, 9))

	# --- enemies: one spawner, two goblins ---
	_add_spawner(entities, "goblin", 2, 50.0, Vector2(10, 6))

	# --- gates (loop to room_01 for the slice) ---
	_add_gate(exits, "E", DOOR_E, "room_01", "default")
	_add_gate(exits, "S", DOOR_S, "room_01", "default")

	# --- spawn points ---
	_add_spawn(spawns, "default", Vector2(4, 6))
	_add_spawn(spawns, "from_02", Vector2(SIZE.x - 3, 5.5))
	_add_spawn(spawns, "from_03", Vector2(8.5, SIZE.y - 3))

	var packed := PackedScene.new()
	if packed.pack(_root) != OK:
		push_error("build_room_01: pack failed.")
		return
	var err := ResourceSaver.save(packed, OUT)
	if err == OK:
		print("build_room_01: wrote ", OUT)
	else:
		push_error("build_room_01: save failed (err %d)" % err)

# ------------------------------------------------------------------- builders

func _build_ground(ts: TileSet) -> void:
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	for y in SIZE.y:
		for x in SIZE.x:
			ground.set_cell(Vector2i(x, y), 0, GROUND_A if (x + y) % 2 == 0 else GROUND_B)
	_attach(ground)

func _build_walls(ts: TileSet) -> void:
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = ts
	for x in SIZE.x:
		walls.set_cell(Vector2i(x, 0), 0, WALL)
		if not DOOR_S.has(x):
			walls.set_cell(Vector2i(x, SIZE.y - 1), 0, WALL)
	for y in SIZE.y:
		walls.set_cell(Vector2i(0, y), 0, WALL)
		if not DOOR_E.has(y):
			walls.set_cell(Vector2i(SIZE.x - 1, y), 0, WALL)
	_attach(walls)

func _build_room_controller() -> void:
	var rc := Node.new()
	rc.name = "RoomController"
	rc.set_script(load("res://systems/room_controller.gd"))
	_attach(rc)

func _build_entities() -> Node2D:
	var e := Node2D.new()
	e.name = "Entities"
	e.y_sort_enabled = true
	_attach(e)
	return e

func _build_exits() -> Node2D:
	var x := Node2D.new()
	x.name = "Exits"
	_attach(x)
	return x

func _build_spawnpoints() -> Node2D:
	var s := Node2D.new()
	s.name = "SpawnPoints"
	_attach(s)
	return s

func _add_prop(parent: Node, scene_path: String, tile: Vector2) -> void:
	var n := (load(scene_path) as PackedScene).instantiate()
	n.position = _cell_center(tile)
	parent.add_child(n)
	n.owner = _root

func _add_spawner(parent: Node, mob_id: String, count: int, spread: float, tile: Vector2) -> void:
	var s := Node2D.new()
	s.set_script(load("res://maps/mob_spawner.gd"))
	s.name = "Spawn_%s" % mob_id
	s.set("mob_id", mob_id)
	s.set("count", count)
	s.set("spread", spread)
	s.position = _cell_center(tile)
	parent.add_child(s)
	s.owner = _root

func _add_spawn(parent: Node, id: String, tile: Vector2) -> void:
	var sp := Marker2D.new()
	sp.set_script(load("res://entities/spawn_point.gd"))
	sp.name = "SpawnPoint_%s" % id
	sp.set("spawn_id", id)
	sp.position = _cell_center(tile)
	parent.add_child(sp)
	sp.owner = _root

func _add_gate(parent: Node, side: String, gap: Array, target_map: String, target_spawn: String) -> void:
	var g := Area2D.new()
	g.set_script(load("res://maps/gate.gd"))
	g.name = "Gate_%s" % side
	g.set("target_map_id", target_map)
	g.set("target_spawn_id", target_spawn)
	var length: int = gap.size()
	var mid: float = float(gap[0]) + float(length) * 0.5 - 0.5
	if side == "E":
		g.set("size_tiles", Vector2(1, length))
		g.position = Vector2(float(SIZE.x - 1) * TILE + TILE * 0.5, mid * TILE + TILE * 0.5)
	elif side == "S":
		g.set("size_tiles", Vector2(length, 1))
		g.position = Vector2(mid * TILE + TILE * 0.5, float(SIZE.y - 1) * TILE + TILE * 0.5)
	parent.add_child(g)
	g.owner = _root

# ------------------------------------------------------------------- helpers

func _attach(n: Node) -> void:
	_root.add_child(n)
	n.owner = _root

func _cell_center(tile: Vector2) -> Vector2:
	return tile * TILE + Vector2(TILE, TILE) * 0.5
