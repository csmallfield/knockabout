extends MapBase
## Room 05 — the HUB and a nasty one: four doors, six mobs incl. a brute and an
## orc, broken walls for cover. Doors N→02, W→03, E→07, S→08.

func _build() -> void:
	map_id = "room_05"
	fill_ground(Vector2i(30, 20))
	border_walls()

	add_spawn("default", Vector2(8, 10))
	add_door("N", 14, 2, "room_02", "from_05", "from_02")
	add_door("W", 9, 2, "room_03", "from_05", "from_03")
	add_door("E", 9, 2, "room_07", "from_05", "from_07")
	add_door("S", 14, 2, "room_08", "from_05", "from_08")

	add_wall_run([Vector2(13, 7), Vector2(14, 7), Vector2(15, 7),
		Vector2(13, 8), Vector2(13, 9)], "wall_segment", "r5_cover_a")
	add_wall_run([Vector2(18, 12), Vector2(18, 13), Vector2(19, 13)],
		"wall_segment", "r5_cover_b")
	place("rock", Vector2(7, 6), "r5_rock_0")
	place("rock", Vector2(23, 14), "r5_rock_1")
	place("barrel", Vector2(11, 15), "r5_barrel_0")
	place("crate", Vector2(24, 7), "r5_crate_0")

	add_mob_spawner("goblin", Vector2(10, 6), 2, 48.0)
	add_mob_spawner("goblin", Vector2(20, 13), 2, 48.0)
	add_mob_spawner("brute", Vector2(8, 14), 1, 0.0)
	add_mob_spawner("orc", Vector2(22, 6), 1, 0.0)
