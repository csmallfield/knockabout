class_name RunOverlay
extends CanvasLayer
## Minimal end-of-run screen. Shown (deferred) on EventBus.run_completed — the
## final room cleared. Pauses the game behind it; offers a restart. Deliberately
## spartan; the UI overhaul is a future session.
##
## The show is DEFERRED by game.gd: run_completed fires synchronously inside the
## dying mob's entity_died callback (during _physics_process), and toggling
## get_tree().paused from inside a physics-signal stack can wedge the frame. We
## also force Engine.time_scale back to 1.0 in case the killing blow's hitstop
## left it near zero (FeedbackManager drives time_scale during hitstop).

signal restart_requested

var _title: Label
var _stats: Label

func _ready() -> void:
	layer = 128                              # top of the stack (HUD 100, fade/debug 120)
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	visible = false

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	# A CenterContainer filling the screen guarantees the content is centred and
	# sized, regardless of resolution — no manual offsets to get wrong.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_title = _label(40, Color(1.0, 0.9, 0.4))
	_title.text = "RUN COMPLETE"
	box.add_child(_title)

	_stats = _label(20, Color(0.95, 0.95, 1.0))
	box.add_child(_stats)

	var btn := Button.new()
	btn.text = "Play again"
	btn.custom_minimum_size = Vector2(180, 44)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_restart)
	box.add_child(btn)

	var hint := _label(13, Color(0.7, 0.7, 0.8))
	hint.text = "(or press Enter)"
	box.add_child(hint)

## Call DEFERRED (game.gd does this). Safe to pause here — we're on an idle frame.
func show_victory(score: int, coins: int) -> void:
	_stats.text = "Final score: %d\nCoins: %d" % [score, coins]
	visible = true
	Engine.time_scale = 1.0          # undo any hitstop still in effect
	get_tree().paused = true

func hide_overlay() -> void:
	visible = false
	Engine.time_scale = 1.0
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_restart()
			get_viewport().set_input_as_handled()

func _on_restart() -> void:
	restart_requested.emit()

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
