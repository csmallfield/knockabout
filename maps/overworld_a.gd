extends MapBase
## Overworld A: the main playground. Building with destructible walls,
## trees/rocks, barrels/crates, three mob types, east exit to Overworld B.


func _build() -> void:
	map_id = "overworld_a"
	fill_ground(Vector2i(40, 24))
	border_walls()
	# East exit gap → Overworld B
	clear_wall(Vector2i(39, 11))
	clear_wall(Vector2i(39, 12))
	add_exit(Rect2(Vector2(39.2, 11), Vector2(1, 2)), "overworld_b", "from_a")

	add_spawn("default", Vector2(6, 12))
	add_spawn("from_b", Vector2(37, 11.5))
	add_spawn("house_door", Vector2(13, 10))

	# Enterable, partially destructible building (§8.3).
	add_building(Rect2i(9, 4, 9, 6), Vector2i(13, 9), "interior_house_a",
		"wall_segment", "house_a")

	# Scatter of trees and rocks.
	for t in [Vector2(5, 5), Vector2(6, 18), Vector2(22, 6), Vector2(30, 18),
			Vector2(25, 14), Vector2(34, 5), Vector2(15, 19)]:
		place("tree", t, "tree_%d_%d" % [int(t.x), int(t.y)])
	for r in [Vector2(28, 9), Vector2(10, 16), Vector2(33, 14)]:
		place("rock", r, "rock_%d_%d" % [int(r.x), int(r.y)])

	# Loose props.
	var i := 0
	for b in [Vector2(20, 12), Vector2(21, 12.6), Vector2(20.5, 13.4),
			Vector2(8, 9), Vector2(31, 8)]:
		place("barrel", b, "barrel_%d" % i)
		i += 1
	place("crate", Vector2(23, 16), "crate_0")
	place("crate", Vector2(7, 14), "crate_1")

	# Mobs (not persisted — fresh per visit).
	_spawner("goblin", Vector2(26, 11), 3)
	_spawner("goblin", Vector2(16, 16), 2)
	_spawner("brute", Vector2(30, 15), 1)
	_spawner("orc", Vector2(34, 10), 1)

func _spawner(id: String, tile: Vector2, count: int) -> void:
	var s := MobSpawner.new()
	s.mob_id = id
	s.count = count
	s.position = tile * T + Vector2(T, T) * 0.5
	entities.add_child(s)
