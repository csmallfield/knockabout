extends MapBase
## Room 03 — large and sparse: the scenic detour. Only three scattered goblins,
## but a lot of ground to cross. Doors N→01, E→05, S→06.

func _build() -> void:
	map_id = "room_03"
	fill_ground(Vector2i(28, 18))
	border_walls()

	add_spawn("default", Vector2(5, 9))
	add_door("N", 13, 2, "room_01", "from_03", "from_01")
	add_door("E", 8, 2, "room_05", "from_03", "from_05")
	add_door("S", 13, 2, "room_06", "from_03", "from_06")

	place("tree", Vector2(5, 4), "r3_tree_0")
	place("tree", Vector2(22, 12), "r3_tree_1")
	place("tree", Vector2(7, 14), "r3_tree_2")
	place("tree", Vector2(24, 4), "r3_tree_3")
	place("rock", Vector2(16, 8), "r3_rock_0")
	place("rock", Vector2(11, 11), "r3_rock_1")

	add_mob_spawner("goblin", Vector2(8, 5), 1, 0.0)
	add_mob_spawner("goblin", Vector2(20, 5), 1, 0.0)
	add_mob_spawner("goblin", Vector2(14, 12), 1, 0.0)
