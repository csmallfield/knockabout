extends MapBase
## Room 07 — mid junction: an orc and two goblins. Doors W→04, N→05, E→09.

func _build() -> void:
	map_id = "room_07"
	fill_ground(Vector2i(20, 14))
	border_walls()

	add_spawn("default", Vector2(8, 8))
	add_door("W", 6, 2, "room_04", "from_07", "from_04")
	add_door("N", 9, 2, "room_05", "from_07", "from_05")
	add_door("E", 6, 2, "room_09", "from_07", "from_09")

	place("crate", Vector2(5, 4), "r7_crate_0")
	place("crate", Vector2(13, 10), "r7_crate_1")
	place("barrel", Vector2(8, 11), "r7_barrel_0")
	place("barrel", Vector2(9, 11.4), "r7_barrel_1")
	place("rock", Vector2(12, 7), "r7_rock_0")

	add_mob_spawner("orc", Vector2(10, 7), 1, 0.0)
	add_mob_spawner("goblin", Vector2(6, 10), 1, 0.0)
	add_mob_spawner("goblin", Vector2(14, 4), 1, 0.0)
