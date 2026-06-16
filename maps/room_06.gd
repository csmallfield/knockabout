extends MapBase
## Room 06 — short but heavy: two brutes and not much room to kite. The "worse"
## branch off room 03. Doors N→03, E→08.

func _build() -> void:
	map_id = "room_06"
	fill_ground(Vector2i(18, 14))
	border_walls()

	add_spawn("default", Vector2(5, 7))
	add_door("N", 8, 2, "room_03", "from_06", "from_03")
	add_door("E", 6, 2, "room_08", "from_06", "from_08")

	place("rock", Vector2(6, 4), "r6_rock_0")
	place("rock", Vector2(12, 10), "r6_rock_1")
	place("rock", Vector2(11, 4), "r6_rock_2")
	place("barrel", Vector2(5, 10), "r6_barrel_0")
	place("barrel", Vector2(6, 10.5), "r6_barrel_1")

	add_mob_spawner("brute", Vector2(9, 7), 2, 60.0)
