extends MapBase
## Room 02 — medium. Three goblins + a brute behind a low wall. Doors W→01,
## E→04, S→05.

func _build() -> void:
	map_id = "room_02"
	fill_ground(Vector2i(20, 14))
	border_walls()

	add_spawn("default", Vector2(10, 7))
	add_door("W", 6, 2, "room_01", "from_02", "from_01")
	add_door("E", 6, 2, "room_04", "from_02", "from_04")
	add_door("S", 9, 2, "room_05", "from_02", "from_05")

	add_wall_run([Vector2(8, 5), Vector2(8, 6), Vector2(8, 7)], "wall_segment", "r2_cover")
	place("crate", Vector2(5, 9), "r2_crate_0")
	place("crate", Vector2(14, 4), "r2_crate_1")
	place("barrel", Vector2(12, 3), "r2_barrel_0")
	place("barrel", Vector2(13, 3.5), "r2_barrel_1")

	add_mob_spawner("goblin", Vector2(6, 4), 2, 48.0)
	add_mob_spawner("goblin", Vector2(13, 9), 1, 0.0)
	add_mob_spawner("brute", Vector2(10, 10), 1, 0.0)
