extends MapBase
## Overworld B: smaller second map proving cross-map persistence (Phase 6).


func _build() -> void:
	map_id = "overworld_b"
	fill_ground(Vector2i(26, 17))
	border_walls()
	# West exit gap → Overworld A
	clear_wall(Vector2i(0, 8))
	clear_wall(Vector2i(0, 9))
	add_exit(Rect2(Vector2(-0.2, 8), Vector2(1, 2)), "overworld_a", "from_b")

	add_spawn("default", Vector2(13, 8))
	add_spawn("from_a", Vector2(2.5, 8.5))

	for t in [Vector2(8, 4), Vector2(18, 12), Vector2(20, 5), Vector2(6, 12)]:
		place("tree", t, "tree_%d_%d" % [int(t.x), int(t.y)])
	place("barrel", Vector2(12, 11), "barrel_0")
	place("barrel", Vector2(13, 11.5), "barrel_1")

	var s := MobSpawner.new()
	s.mob_id = "goblin"
	s.count = 3
	s.position = Vector2(17, 8) * T
	entities.add_child(s)
	var s2 := MobSpawner.new()
	s2.mob_id = "brute"
	s2.count = 1
	s2.position = Vector2(20, 10) * T
	entities.add_child(s2)
