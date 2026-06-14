class_name BuildingRoof
extends Node2D
## Roof sprite drawn above everything; goes translucent while the player
## stands inside the footprint (e.g. after smashing through a wall) (§8.3).

var size_px := Vector2.ZERO
var _inside := false

func _ready() -> void:
	z_index = 100
	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = Tuning.L_PLAYER
	var cs := EntityKit.rect_collider(size_px)
	cs.position = size_px * 0.5
	zone.add_child(cs)
	zone.body_entered.connect(func(_b: Node) -> void: _inside = true)
	zone.body_exited.connect(func(_b: Node) -> void: _inside = false)
	add_child(zone)

func _process(_delta: float) -> void:
	modulate.a = move_toward(modulate.a, 0.25 if _inside else 1.0, 0.08)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_px), Color(0.45, 0.22, 0.18))
	draw_rect(Rect2(Vector2.ZERO, size_px), Color(0.3, 0.14, 0.12), false, 3.0)
