class_name MiniHealthBar
extends Node2D
## Tiny floating HP bar. Hidden until the owner first takes damage ("engaged"),
## then tracks the ratio. Fill color shifts green → red as HP drops.

var width := 22.0
var ratio := 1.0

const HEIGHT := 3.0

func set_ratio(r: float) -> void:
	ratio = clampf(r, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var half_w := width * 0.5
	draw_rect(Rect2(-half_w - 1.0, -HEIGHT * 0.5 - 1.0, width + 2.0, HEIGHT + 2.0),
		Color(0.0, 0.0, 0.0, 0.65))
	var fill := Color(0.85, 0.2, 0.2).lerp(Color(0.35, 0.8, 0.3), ratio)
	draw_rect(Rect2(-half_w, -HEIGHT * 0.5, width * ratio, HEIGHT), fill)
