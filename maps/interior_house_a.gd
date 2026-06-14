extends MapBase
## Interior of the Overworld A building. Deliberately roomier than the
## exterior footprint (genre-standard, §8.3).


func _build() -> void:
	map_id = "interior_house_a"
	fill_ground(Vector2i(16, 11))
	border_walls()
	# Door at the bottom → back outside (auto on touch).
	clear_wall(Vector2i(8, 10))
	add_exit(Rect2(Vector2(8, 10.2), Vector2(1, 1)), "overworld_a", "house_door")

	add_spawn("default", Vector2(8, 8.5))

	place("crate", Vector2(3, 3), "crate_0")
	place("crate", Vector2(4, 3), "crate_1")
	place("barrel", Vector2(12, 4), "barrel_0")
