class_name PoseSheet
extends Node
## Staged pose sheet of the hero puppet, for checking it by eye:
##   godot --path . -- --pose-sheet
## Clears the room, drives the player through facings, swings, block, roll and
## charge, and saves a strip of crops round the player to user://pose_sheet.png.
## Needs a real renderer (not --headless).
var _t := 0.0
var _shots := []
const STEPS := [
	["move_right", "", 0.5], ["move_right", "attack", 0.265], ["move_right", "attack", 0.3],
	["move_left", "", 0.5], ["move_left", "attack", 0.28], ["move_down", "", 0.5], ["move_down", "attack", 0.28],
	["move_up", "", 0.5], ["move_up", "attack", 0.28], ["move_right", "block", 0.6], ["move_down", "roll", 0.33],
	["move_right", "charge", 0.7],
]
var _i := 0
var _st := 0.0
func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or MapManager.current_map == null:
		return
	_t += delta
	for m in get_tree().get_nodes_in_group("mobs"):
		m.queue_free()
	if _t < 0.5:
		return
	_st += delta
	for a in ["move_right", "move_left", "move_up", "move_down", "attack", "block", "roll"]:
		Input.action_release(a)
	if _i >= STEPS.size():
		var out := Image.create_empty(160 * _shots.size(), 200, false, Image.FORMAT_RGBA8)
		for k in _shots.size():
			out.blit_rect(_shots[k], Rect2i(0, 0, 160, 200), Vector2i(160 * k, 0))
		out.save_png("user://pose_sheet.png")
		print("PoseSheet: ", ProjectSettings.globalize_path("user://pose_sheet.png"))
		get_tree().quit()
		return
	var s: Array = STEPS[_i]
	if _st < 0.12:
		Input.action_press(s[0], 0.25)       # turn to face, barely move
	if s[1] in ["attack", "roll"] and _st > 0.2 and _st < 0.24:
		Input.action_press(s[1])
	if s[1] == "charge" and _st > 0.2:
		Input.action_press("attack")
	if s[1] == "block" and _st > 0.2:
		Input.action_press("block")
	if _st >= s[2]:
		var img := get_viewport().get_texture().get_image()
		var sp := get_viewport().get_canvas_transform() * player.global_position
		var k := Vector2(img.get_size()) / get_viewport().get_visible_rect().size
		var c := Vector2i(sp * k)
		_shots.append(img.get_region(Rect2i(c.x - 80, c.y - 130, 160, 200)))
		_i += 1
		_st = 0.0
