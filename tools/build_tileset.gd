@tool
extends EditorScript
## Builds res://maps/knockabout_tileset.tres — the shared TileSet for every room.
##
## RUN IT: open this file in the script editor, then File > Run (Ctrl+Shift+X).
## Idempotent — overwrites the .tres each run. Re-run after you tweak the art or
## want more wall variants.
##
## Reproduces the old runtime tileset (ground A/B + wall) and adds the two things
## the editor workflow needs:
##   • a physics layer on WORLD with a full-cell collision polygon on wall tiles
##   • a "restitution" custom-data layer (float) so each wall tile can bounce
##     differently — the per-surface gameplay lever
##
## The atlas texture is generated in code (flat colours, matching the prototype's
## placeholder language) and embedded in the .tres, so this is the only file you
## need — no separate PNG to import.

const OUT := "res://maps/knockabout_tileset.tres"
const TILE := 32

# Atlas columns (x in tiles). Paint Ground from 0/1, Walls from 2 (neutral) or
# 3 (bouncy). Restitution per wall: neutral matches the old STATIC_RESTITUTION.
const GROUND_A := Vector2i(0, 0)
const GROUND_B := Vector2i(1, 0)
const WALL_NEUTRAL := Vector2i(2, 0)
const WALL_BOUNCY := Vector2i(3, 0)

func _run() -> void:
	var img := Image.create(TILE * 4, TILE, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, TILE, TILE), Color(0.32, 0.46, 0.27))            # ground A
	img.fill_rect(Rect2i(TILE, 0, TILE, TILE), Color(0.30, 0.43, 0.25))         # ground B
	img.fill_rect(Rect2i(TILE * 2, 0, TILE, TILE), Color(0.25, 0.24, 0.28))     # wall neutral
	img.fill_rect(Rect2i(TILE * 2 + 2, 2, TILE - 4, TILE - 4), Color(0.33, 0.32, 0.37))
	img.fill_rect(Rect2i(TILE * 3, 0, TILE, TILE), Color(0.20, 0.28, 0.40))     # wall bouncy (blue tint)
	img.fill_rect(Rect2i(TILE * 3 + 2, 2, TILE - 4, TILE - 4), Color(0.30, 0.45, 0.70))

	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	# Physics layer 0 → WORLD. Literal 1 (not Tuning.L_WORLD): this is an
	# EditorScript and the Tuning autoload node isn't live in the editor.
	const WORLD_BIT := 1   # == Tuning.L_WORLD
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, WORLD_BIT)
	ts.set_physics_layer_collision_mask(0, 0)

	# Custom data layer 0 → restitution (float).
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "restitution")
	ts.set_custom_data_layer_type(0, TYPE_FLOAT)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	for i in 4:
		src.create_tile(Vector2i(i, 0))

	# Ground tiles: no collision; restitution irrelevant (never collided with).
	# Wall tiles: full-cell collider + their restitution. Neutral = 0.5 (the old
	# Tuning.STATIC_RESTITUTION, so unchanged feel); bouncy = 0.9.
	_make_wall(src, WALL_NEUTRAL, 0.5)
	_make_wall(src, WALL_BOUNCY, 0.9)

	var err := ResourceSaver.save(ts, OUT)
	if err == OK:
		print("build_tileset: wrote ", OUT)
	else:
		push_error("build_tileset: save failed (err %d)" % err)

func _make_wall(src: TileSetAtlasSource, coords: Vector2i, restitution: float) -> void:
	var td := src.get_tile_data(coords, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))
	td.set_custom_data("restitution", restitution)
