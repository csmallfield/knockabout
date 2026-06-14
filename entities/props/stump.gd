extends Node2D
## Tree stump: non-blocking decor remnant (GDD §8.1).

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color(0.42, 0.3, 0.2))
	draw_circle(Vector2.ZERO, 5.0, Color(0.55, 0.42, 0.3))
