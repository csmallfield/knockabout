extends CanvasLayer
## HUD (GDD §10 + scoring/loot §7). Reads ONLY EventBus + ScoreManager signals,
## so the player/score systems never need a reference to UI. Reuses the existing
## StyleBoxFlat bar approach.

var _hp_bar: ProgressBar
var _power_bar: ProgressBar
var _power_badge: Label
var _score_label: Label
var _coin_label: Label

func _ready() -> void:
	layer = 100

	_hp_bar = _make_bar(Vector2(12, 12), Color(0.85, 0.22, 0.25))
	add_child(_hp_bar)

	_power_bar = _make_bar(Vector2(12, 32), Color(0.55, 0.35, 0.9))
	_power_bar.min_value = 0.0
	_power_bar.max_value = 1.0
	_power_bar.value = 0.0
	add_child(_power_bar)

	_power_badge = _make_label(Vector2(180, 28), 16)
	_power_badge.text = "×1"
	add_child(_power_badge)

	_score_label = _make_label(Vector2(12, 54), 18)
	_score_label.text = "Score 0"
	add_child(_score_label)

	_coin_label = _make_label(Vector2(12, 78), 14)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	_coin_label.text = "Coins 0"
	add_child(_coin_label)

	EventBus.player_hp_changed.connect(_on_hp_changed)
	ScoreManager.score_changed.connect(_on_score_changed)
	ScoreManager.power_changed.connect(_on_power_changed)
	ScoreManager.coins_changed.connect(_on_coins_changed)

func _make_bar(pos: Vector2, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 14)
	bar.position = pos
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.1, 0.85)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _make_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l

func _on_hp_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp

func _on_score_changed(score: float) -> void:
	_score_label.text = "Score %d" % int(round(score))

func _on_power_changed(level: int, meter_ratio: float) -> void:
	_power_bar.value = meter_ratio
	_power_badge.text = "×%d" % (1 + level)

func _on_coins_changed(total: int) -> void:
	_coin_label.text = "Coins %d" % total
