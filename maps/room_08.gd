extends MapBase
## Room 08 — big and dangerous: brute + orc + three goblins, plenty of cover to
## fight around. Doors N→05, W→06, E→09.

func _build() -> void:
	map_id = "room_08"
	fill_ground(Vector2i(26, 18))
	border_walls()

	add_spawn("default", Vector2(7, 10))
	add_door("N", 12, 2, "room_05", "from_08", "from_05")
	add_door("W", 8, 2, "room_06", "from_08", "from_06")
	add_door("E", 8, 2, "room_09", "from_08", "from_09")

	add_wall_run([Vector2(12, 6), Vector2(13, 6), Vector2(12, 7)],
		"wall_segment", "r8_cover_a")
	add_wall_run([Vector2(16, 11), Vector2(16, 12), Vector2(17, 12)],
		"wall_segment", "r8_cover_b")
	place("rock", Vector2(9, 8), "r8_rock_0")
	place("rock", Vector2(20, 14), "r8_rock_1")
	place("crate", Vector2(6, 14), "r8_crate_0")
	place("barrel", Vector2(19, 5), "r8_barrel_0")
	place("barrel", Vector2(20, 5.5), "r8_barrel_1")

	add_mob_spawner("goblin", Vector2(8, 5), 2, 46.0)
	add_mob_spawner("goblin", Vector2(16, 13), 1, 0.0)
	add_mob_spawner("brute", Vector2(10, 12), 1, 0.0)
	add_mob_spawner("orc", Vector2(18, 7), 1, 0.0)
