class_name EntityKit
extends Object
## Shared builders for code-constructed entity internals.

static func circle_collider(radius: float) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	return cs

static func rect_collider(size: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	return cs

## Area2D on the HURTBOX layer; the universal damage receiver tag (GDD §10).
static func make_hurtbox(radius: float, rect := Vector2.ZERO) -> Area2D:
	var area := Area2D.new()
	area.name = "Hurtbox"
	area.collision_layer = Tuning.L_HURTBOX
	area.collision_mask = 0
	area.monitoring = false
	area.add_child(rect_collider(rect) if rect != Vector2.ZERO else circle_collider(radius + 2.0))
	return area

## Resolve an overlapped hurtbox Area2D back to its entity root.
static func hurtbox_entity(area: Area2D) -> Node:
	var p := area.get_parent()
	return p if p and p.has_method("get_stats") else null
