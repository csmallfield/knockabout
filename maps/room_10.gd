extends MapBase
## Room 10 — FINAL ARENA (leaf). One way in (W→09). Orc + brute + two goblins
## around central cover. Clearing this room ends the run. is_final is set here in
## script (authoritative) so the win condition can't be lost to a scene-file quirk.

func _build() -> void:
	map_id = "room_10"
	is_final = true   # MapBase reads this after _build to arm the win condition
	fill_ground(Vector2i(22, 16))
	border_walls()

	add_spawn("default", Vector2(3, 8))
	add_door("W", 7, 2, "room_09", "from_10", "from_09")

	add_wall_run([Vector2(11, 7), Vector2(12, 7), Vector2(11, 8)],
		"wall_segment", "r10_cover")
	place("rock", Vector2(15, 5), "r10_rock_0")
	place("rock", Vector2(9, 11), "r10_rock_1")
	place("crate", Vector2(16, 11), "r10_crate_0")

	add_mob_spawner("goblin", Vector2(13, 4), 2, 46.0)
	add_mob_spawner("orc", Vector2(16, 8), 1, 0.0)
	add_mob_spawner("brute", Vector2(11, 11), 1, 0.0)
