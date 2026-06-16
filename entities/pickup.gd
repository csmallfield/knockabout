class_name Pickup
extends Area2D
## Pooled loot token (GDD §6.2). Lives under PickupPool in global coords,
## mirroring DebrisShard. Re-configured per spawn from a LootProfile.
##
## Detection is pickup-side: this Area2D monitors the player body (L_PLAYER)
## rather than relying on the player's mask, so it mirrors how hurtboxes work
## here and needs no change to the player's collision setup.

var active := false
var spawn_time := 0.0

const MAGNET_SPEED := 320.0   ## px/s drift once inside magnetize_radius
const MAGNET_LERP := 8.0      ## how fast we converge onto that drift
const COAST_LERP := 6.0       ## settle-to-rest when not magnetized

var _profile: LootProfile
var _velocity := Vector2.ZERO
var _age := 0.0
var _player: Node2D
var _art: PickupArt
var _shape: CollisionShape2D

func _ready() -> void:
	collision_layer = Tuning.L_LOOT
	collision_mask = Tuning.L_PLAYER
	monitoring = false
	_shape = EntityKit.circle_collider(6.0)
	add_child(_shape)
	_art = PickupArt.new()
	add_child(_art)
	body_entered.connect(_on_body_entered)
	deactivate()

func activate(pos: Vector2, vel: Vector2, profile: LootProfile) -> void:
	_profile = profile
	_velocity = vel
	_age = 0.0
	global_position = pos
	(_shape.shape as CircleShape2D).radius = profile.radius
	_art.color = profile.color
	_art.radius = profile.radius
	_art.queue_redraw()
	active = true
	visible = true
	modulate.a = 1.0
	spawn_time = Time.get_ticks_msec() / 1000.0
	set_deferred("monitoring", true)
	_shape.set_deferred("disabled", false)
	_player = get_tree().get_first_node_in_group("player") as Node2D

func deactivate() -> void:
	active = false
	visible = false
	_profile = null
	set_deferred("monitoring", false)
	if _shape:
		_shape.set_deferred("disabled", true)

func _physics_process(delta: float) -> void:
	if not active:
		return
	_age += delta

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D

	# Magnetize toward the player once close; otherwise coast and settle.
	if _player and global_position.distance_to(_player.global_position) <= _profile.magnetize_radius:
		var to := (_player.global_position - global_position).normalized()
		_velocity = _velocity.lerp(to * MAGNET_SPEED, clampf(MAGNET_LERP * delta, 0.0, 1.0))
	else:
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(COAST_LERP * delta, 0.0, 1.0))
	global_position += _velocity * delta

	# Lifetime + last-second fade (0 = forever).
	if _profile.lifetime > 0.0:
		if _age > _profile.lifetime:
			deactivate()
		elif _age > _profile.lifetime - 1.0:
			modulate.a = _profile.lifetime - _age

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.is_in_group("player") and body.has_method("collect"):
		body.collect(_profile)
		deactivate()

## Placeholder loot art: filled disc + rim, styled by the profile (matches the
## colored-circle placeholder language of the rest of the prototype).
class PickupArt:
	extends Node2D
	var color := Color.WHITE
	var radius := 6.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, color.lerp(Color.WHITE, 0.45), 1.5)
