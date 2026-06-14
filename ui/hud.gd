extends CanvasLayer
## Minimal HUD (GDD §10): an HP bar. Reads ONLY EventBus signals so the
## player node never needs a reference to UI.

var _bar: ProgressBar

func _ready() -> void:
	layer = 100
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(160, 14)
	_bar.position = Vector2(12, 12)
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 100.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.22, 0.25)
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)

	add_child(_bar)
	EventBus.player_hp_changed.connect(_on_hp_changed)

func _on_hp_changed(hp: float, max_hp: float) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
