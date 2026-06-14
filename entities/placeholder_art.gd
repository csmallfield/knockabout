class_name PlaceholderArt
extends Node2D
## Flat-color placeholder sprite (D4): circle or rect + facing tick mark.
## Also owns the per-entity juice: flash-white and launch squash (§12).

@export var color := Color.WHITE
@export var radius := 10.0
@export var rect_size := Vector2.ZERO   # non-zero ⇒ draw a rect instead
@export var show_facing := false

var facing := Vector2.DOWN:
	set(v):
		facing = v
		queue_redraw()

var _flash := 0.0
var _tween: Tween

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 6.0, 0.0)
		queue_redraw()

func _draw() -> void:
	var c := color.lerp(Color.WHITE, _flash)
	if rect_size != Vector2.ZERO:
		draw_rect(Rect2(-rect_size * 0.5, rect_size), c)
		draw_rect(Rect2(-rect_size * 0.5, rect_size), c.darkened(0.35), false, 2.0)
	else:
		draw_circle(Vector2.ZERO, radius, c)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, c.darkened(0.35), 2.0)
	if show_facing:
		draw_line(facing * radius * 0.4, facing * (radius + 4.0), c.darkened(0.5), 3.0)

func flash() -> void:
	_flash = 1.0
	queue_redraw()

func squash() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector2(1.3, 0.7)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
