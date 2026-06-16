extends MapBase
## Room 09 — pre-final gauntlet: two orcs and two goblins. Last junction before
## the end. Doors W→07, S→08, E→10.

func _build() -> void:
	map_id = "room_09"
	fill_ground(Vector2i(22, 16))
	border_walls()

	add_spawn("default", Vector2(6, 8))
	add_door("W", 7, 2, "room_07", "from_09", "from_07")
	add_door("S", 10, 2, "room_08", "from_09", "from_08")
	add_door("E", 7, 2, "room_10", "from_09", "from_10")

	place("rock", Vector2(9, 6), "r9_rock_0")
	place("rock", Vector2(14, 10), "r9_rock_1")
	place("rock", Vector2(12, 4), "r9_rock_2")
	place("crate", Vector2(6, 12), "r9_crate_0")

	add_mob_spawner("orc", Vector2(11, 5), 1, 0.0)
	add_mob_spawner("orc", Vector2(14, 10), 1, 0.0)
	add_mob_spawner("goblin", Vector2(7, 11), 2, 46.0)
