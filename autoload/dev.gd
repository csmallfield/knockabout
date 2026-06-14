extends Node
## Debug tooling (GDD §13). Entirely inert in release exports:
## every hook early-outs unless OS.is_debug_build().

const GOBLIN := "goblin"
const BRUTE := "brute"
const ORC := "orc"
const BARREL := "barrel"

var _overlay: CanvasLayer
var _label: Label
var _visible := false

func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_key_input(false)
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_overlay.add_child(_label)
	_overlay.visible = false
	add_child(_overlay)

func _process(_delta: float) -> void:
	if not _visible:
		return
	var ballistic := 0
	for n in get_tree().get_nodes_in_group("ballistic"):
		if n.has_method("is_ballistic") and n.is_ballistic():
			ballistic += 1
	_label.text = "FPS %d\nphysics bodies %d\nballistic actors %d\nlive debris %d\nimpacts this tick %d" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS),
		ballistic,
		DebrisPool.live_count(),
		ImpactResolver.impacts_this_tick,
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			_visible = not _visible
			_overlay.visible = _visible
		KEY_F2:
			_spawn_at_mouse(GOBLIN)
		KEY_F3:
			_spawn_at_mouse(BRUTE)
		KEY_F4:
			_spawn_at_mouse(ORC)
		KEY_F5:
			_spawn_at_mouse(BARREL)
		KEY_F6:
			_clear_mobs()
		KEY_F7:
			_refill_player()
		KEY_F8:
			_toggle_collision_shapes()
		KEY_F9:
			_stress_test()

func _spawn_at_mouse(id: String) -> Node:
	var map := MapManager.current_map
	if map == null:
		return null
	var n := Registry.spawn(id)
	if n == null:
		return null
	map.entities.add_child(n)
	n.global_position = map.get_global_mouse_position()
	return n

func _clear_mobs() -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		m.queue_free()

func _refill_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.heal_full()

func _toggle_collision_shapes() -> void:
	# Runtime equivalent of Debug > Visible Collision Shapes.
	var tree := get_tree()
	tree.debug_collisions_hint = not tree.debug_collisions_hint
	# Force re-draw by nudging every collision object (cheap prototype trick:
	# shapes pick the hint up when (re)entering the tree).
	for n in tree.get_nodes_in_group("ballistic"):
		var p := n.get_parent()
		var idx := n.get_index()
		p.remove_child(n)
		p.add_child(n)
		p.move_child(n, idx)

func _stress_test() -> void:
	var map := MapManager.current_map
	if map == null:
		return
	var center := map.get_global_mouse_position()
	for i in 20:
		var id: String = [GOBLIN, GOBLIN, BRUTE, ORC][i % 4]
		var n := Registry.spawn(id)
		if n == null:
			continue
		map.entities.add_child(n)
		n.global_position = center + Vector2(randf_range(-160, 160), randf_range(-120, 120))
	for i in 12:
		var b := Registry.spawn(BARREL)
		if b == null:
			continue
		map.entities.add_child(b)
		b.global_position = center + Vector2(randf_range(-200, 200), randf_range(-150, 150))
