extends Node
## Map registry + transitions (GDD §9.2). The player node persists across
## maps; it's reparented into each map's y-sorted Entities node so depth
## sorting against trees/props works.

const MAPS := {
	"overworld_a": "res://maps/overworld_a.tscn",
	"overworld_b": "res://maps/overworld_b.tscn",
	"interior_house_a": "res://maps/interior_house_a.tscn",
}

var current_map_id := ""
var current_map: MapBase
var _busy := false
var _fade: ColorRect

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.anchors_preset = Control.PRESET_FULL_RECT
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	add_child(layer)

func start(map_id: String, spawn_id := "default") -> void:
	_load_map(map_id, spawn_id)

func change_map(map_id: String, spawn_id := "default") -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.25)
	await tw.finished
	_load_map(map_id, spawn_id)
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.25)
	await tw2.finished
	_busy = false

func respawn_player() -> void:
	# D6: fade, respawn at current map's default spawn, full HP, mobs reset
	# (the whole map reloads; spawners re-arm, destruction persists via WorldState).
	if _busy:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.heal_full()
	await change_map(current_map_id, "default")

func _load_map(map_id: String, spawn_id: String) -> void:
	assert(MAPS.has(map_id), "Unknown map_id: " + map_id)
	var game := get_tree().get_first_node_in_group("game")
	var holder: Node = game.get_node("MapHolder")
	var player: Node2D = get_tree().get_first_node_in_group("player")

	if player.get_parent():
		player.get_parent().remove_child(player)
	for child in holder.get_children():
		child.free()   # immediate: old map fully gone before the new one loads

	current_map_id = map_id
	var map: MapBase = (load(MAPS[map_id]) as PackedScene).instantiate()
	current_map = map
	holder.add_child(map)

	var spawn: Vector2 = map.spawn_points.get(spawn_id,
		map.spawn_points.get("default", map.bounds.get_center()))
	map.entities.add_child(player)
	player.global_position = spawn
	player.set_camera_limits(map.bounds)
	EventBus.map_changed.emit(map_id)
