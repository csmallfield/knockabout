class_name MobGrid
extends RefCounted
## A spatial hash of the live mobs' positions, rebuilt at most once per
## physics tick and shared by every brain. Replaces each brain scanning the
## whole "mobs" group for separation (n² per tick: at 120 mobs that was a
## large share of the frame) with a 3x3-cell lookup over cached positions.
## Same neighbours as the scan as long as CELL is at least the largest
## separation radius (BrainProfile.separation_radius, 46 for the orc).

const CELL := 48.0

static var _frame := -1
static var _cells := {}          # Vector2i -> Array of Vector2

## The separation push for a mob at `here`: the sum over other mobs within
## `radius` of (away direction × (1 - dist / radius)), as MobBrain had it.
static func separation(tree: SceneTree, here: Vector2, radius: float) -> Vector2:
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_rebuild(tree)
	var c := Vector2i(floori(here.x / CELL), floori(here.y / CELL))
	var push := Vector2.ZERO
	var r2 := radius * radius
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var bucket: Variant = _cells.get(Vector2i(c.x + dx, c.y + dy))
			if bucket == null:
				continue
			for p: Vector2 in (bucket as Array):
				var d := here - p
				var dd := d.length_squared()
				if dd > 0.0001 and dd < r2:
					var dist := sqrt(dd)
					push += d / dist * (1.0 - dist / radius)
	return push

static func _rebuild(tree: SceneTree) -> void:
	_cells.clear()
	for m in tree.get_nodes_in_group("mobs"):
		var n := m as Node2D
		if n == null:
			continue
		var p := n.global_position
		var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
		var bucket: Variant = _cells.get(c)
		if bucket == null:
			_cells[c] = [p]
		else:
			(bucket as Array).append(p)
