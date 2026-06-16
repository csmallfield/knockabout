class_name Gate
extends Area2D
## A lockable door (the §8.3 door, upgraded for the room-clear loop). It is
## three things in one placeholder node:
##   1. an Area2D trigger (L_INTERACT, sensing the player) that fires the map
##      transition — but only while OPEN;
##   2. a child StaticBody2D on L_WORLD that physically seals the doorway while
##      LOCKED (so the player — and mobs — can't leave an uncleared room);
##   3. a drawn placeholder bar that reads as a closed portcullis when locked
##      and retracts + greens when open.
##
## Each room owns its own gates; a door between rooms A and B is a Gate in A and
## a separate Gate in B. Locking is therefore per-room: every gate in a room is
## locked on entry-while-uncleared and opened together when the room clears
## (RoomController drives this). No per-door bookkeeping is needed — room-clear
## state lives in WorldState.

@export var target_map_id := ""
@export var target_spawn_id := "default"

var size_px := Vector2(T, T * 2.0)

const T := 32.0

var _open := false
var _blocker: StaticBody2D
var _blocker_shape: CollisionShape2D
var _art: GateArt
var _anim: Tween

func _ready() -> void:
	# Trigger: senses the player, fires the transition (only while open).
	collision_layer = Tuning.L_INTERACT
	collision_mask = Tuning.L_PLAYER
	monitoring = false
	add_child(_rect_shape(size_px))

	# Physical seal: blocks anything that masks L_WORLD (player + mobs).
	_blocker = StaticBody2D.new()
	_blocker.collision_layer = Tuning.L_WORLD
	_blocker.collision_mask = 0
	_blocker_shape = _rect_shape(size_px)
	_blocker.add_child(_blocker_shape)
	add_child(_blocker)

	_art = GateArt.new()
	_art.size_px = size_px
	add_child(_art)

	body_entered.connect(_on_body_entered)
	lock()   # gates default to locked; the RoomController opens them on clear

func lock() -> void:
	_open = false
	set_deferred("monitoring", false)
	_blocker_shape.set_deferred("disabled", false)
	if _anim and _anim.is_valid():
		_anim.kill()
	_art.set_open_amount(0.0)
	_art.locked = true
	_art.queue_redraw()

## celebrate: a fresh in-play clear retracts with a little flourish; a room that
## was already cleared on entry just snaps open quietly.
func open(celebrate := true) -> void:
	if _open:
		return
	_open = true
	_art.locked = false
	_blocker_shape.set_deferred("disabled", true)
	set_deferred("monitoring", true)   # NOTE: does not retro-fire for a body
	# already standing in the doorway — which is what we want (no accidental
	# instant transition the moment a room clears).
	if _anim and _anim.is_valid():
		_anim.kill()
	if celebrate:
		_anim = create_tween()
		_anim.tween_method(_art.set_open_amount, 0.0, 1.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_art.set_open_amount(1.0)

func is_open() -> bool:
	return _open

func _rect_shape(sz: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	cs.shape = rect
	return cs

func _on_body_entered(body: Node) -> void:
	if _open and body.is_in_group("player"):
		MapManager.change_map(target_map_id, target_spawn_id)

## Placeholder door art: a framed bar that slides away as it opens. Colours
## match the prototype's flat-shape language (iron when shut, green when open).
class GateArt:
	extends Node2D
	var size_px := Vector2(32, 64)
	var locked := true
	var _open_amount := 0.0   # 0 = shut, 1 = fully retracted

	func set_open_amount(a: float) -> void:
		_open_amount = clampf(a, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var half := size_px * 0.5
		var frame := Color(0.18, 0.18, 0.22)
		# Door frame (always drawn, sells the opening even when retracted).
		draw_rect(Rect2(-half, size_px), frame, false, 3.0)
		if _open_amount >= 0.999:
			return
		# The leaf retracts along its long axis.
		var vertical := size_px.y >= size_px.x
		var leaf := size_px
		if vertical:
			leaf.y = size_px.y * (1.0 - _open_amount)
		else:
			leaf.x = size_px.x * (1.0 - _open_amount)
		var shut := Color(0.34, 0.12, 0.12) if locked else Color(0.2, 0.5, 0.24)
		draw_rect(Rect2(-leaf * 0.5, leaf), shut)
		draw_rect(Rect2(-leaf * 0.5, leaf), shut.darkened(0.3), false, 2.0)
		# A couple of bars so it reads as a portcullis, not just a block.
		var accent := shut.lerp(Color.BLACK, 0.35)
		if vertical:
			var n := 3
			for i in range(1, n):
				var y := -leaf.y * 0.5 + leaf.y * float(i) / float(n)
				draw_line(Vector2(-leaf.x * 0.5, y), Vector2(leaf.x * 0.5, y), accent, 2.0)
		else:
			var n := 3
			for i in range(1, n):
				var x := -leaf.x * 0.5 + leaf.x * float(i) / float(n)
				draw_line(Vector2(x, -leaf.y * 0.5), Vector2(x, leaf.y * 0.5), accent, 2.0)
