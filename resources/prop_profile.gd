class_name PropProfile
extends Resource
## One prop/block type = one file. body_type picks the physics root:
## LOOSE → RigidBody2D (barrels), ANCHORED → StaticBody2D (trees, walls).

enum BodyType { LOOSE, ANCHORED }

@export var stats: PhysicsStats
@export var body_type := BodyType.LOOSE

@export_group("Shape")
@export var radius := 10.0                  # used when rect_size is zero
@export var rect_size := Vector2.ZERO       # non-zero ⇒ rectangle

@export_group("Visual")
@export var color := Color(0.7, 0.5, 0.3)
