extends MapBase
## Room 04 — tight box, four goblins packed in. Quick but crowded. Doors W→02,
## E→07.

func _build() -> void:
	map_id = "room_04"
	fill_ground(Vector2i(14, 10))
	border_walls()

	add_spawn("default", Vector2(7, 5))
	add_door("W", 4, 2, "room_02", "from_04", "from_02")
	add_door("E", 4, 2, "room_07", "from_04", "from_07")

	place("crate", Vector2(4, 7), "r4_crate_0")
	place("crate", Vector2(9, 7), "r4_crate_1")
	place("crate", Vector2(6, 2), "r4_crate_2")

	add_mob_spawner("goblin", Vector2(7, 5), 4, 42.0)
