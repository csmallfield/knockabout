extends MapBase
## Room 01 — START. Small, gentle intro: two goblins, a little cover. Doors E→02
## and S→03. Doors are sealed until both goblins are down.

func _build() -> void:
	map_id = "room_01"
	fill_ground(Vector2i(18, 12))
	border_walls()

	add_spawn("default", Vector2(4, 6))                       # run start
	add_door("E", 5, 2, "room_02", "from_01", "from_02")
	add_door("S", 8, 2, "room_03", "from_01", "from_03")

	place("barrel", Vector2(6, 3), "r1_barrel_0")
	place("barrel", Vector2(7, 3.5), "r1_barrel_1")
	place("tree", Vector2(12, 8), "r1_tree_0")
	place("rock", Vector2(5, 9), "r1_rock_0")

	add_mob_spawner("goblin", Vector2(10, 6), 2, 50.0)
