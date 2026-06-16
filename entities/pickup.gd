class_name Pickup
extends Area2D
## Pooled loot token (GDD §6.2 + visual polish). Lives under PickupPool in
## global coords, mirroring DebrisShard. Re-configured per spawn from a
## LootProfile.
##
## It pops out of the kill, scatters, and LANDS during a short arm window before
## it can be collected or magnetized — so even point-blank melee drops are
## visibly on the ground for a beat instead of being vacuumed up in one frame.
##
## Detection is pickup-side: this Area2D monitors the player body (L_PLAYER).

var active := false
var spawn_time := 0.0

const ARM_TIME := 0.4         ## s before collectible / magnetizing (visible drop)
const ARM_DRAG := 9.0         ## /s velocity decay while settling (lands fast)
const LAND_DRAG := 6.0        ## /s decay when armed but out of magnet range
const MAGNET_SPEED := 320.0   ## px/s drift once inside magnetize_radius
const MAGNET_LERP := 8.0      ## convergence onto that drift

var _profile: LootProfile
var _velocity := Vector2.ZERO
var _age := 0.0
var _armed := false
var _player: Node2D
var _art: PickupArt
var _shape: CollisionShape2D
var _pop: Tween

func _ready() -> void:
	collision_layer = Tuning.L_LOOT
	collision_mask = Tuning.L_PLAYER
	z_index = 6   # pools live under an autoload (drawn before the scene) → lift above the map
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
	_armed = false
	global_position = pos
	(_shape.shape as CircleShape2D).radius = profile.radius
	_art.setup(profile)
	active = true
	visible = true
	modulate.a = 1.0
	spawn_time = Time.get_ticks_msec() / 1000.0
	set_deferred("monitoring", false)        # not collectible until armed
	_shape.set_deferred("disabled", true)
	_player = get_tree().get_first_node_in_group("player") as Node2D
	# Pop-in scale with a little overshoot.
	if _pop and _pop.is_valid():
		_pop.kill()
	_art.scale = Vector2.ZERO
	_pop = create_tween()
	_pop.tween_property(_art, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func deactivate() -> void:
	active = false
	visible = false
	_armed = false
	_profile = null
	set_deferred("monitoring", false)
	if _shape:
		_shape.set_deferred("disabled", true)
	if _pop and _pop.is_valid():
		_pop.kill()
	if _art:
		_art.scale = Vector2.ONE

func _physics_process(delta: float) -> void:
	if not active:
		return
	_age += delta

	if _age < ARM_TIME:
		# Settling: the scatter velocity bleeds off so the token visibly lands.
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(ARM_DRAG * delta, 0.0, 1.0))
	else:
		if not _armed:
			_armed = true
			set_deferred("monitoring", true)
			_shape.set_deferred("disabled", false)
		if _player == null or not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player and global_position.distance_to(_player.global_position) <= _profile.magnetize_radius:
			var to := (_player.global_position - global_position).normalized()
			_velocity = _velocity.lerp(to * MAGNET_SPEED, clampf(MAGNET_LERP * delta, 0.0, 1.0))
		else:
			_velocity = _velocity.lerp(Vector2.ZERO, clampf(LAND_DRAG * delta, 0.0, 1.0))
	global_position += _velocity * delta

	# Lifetime + last-second fade (0 = forever).
	if _profile.lifetime > 0.0:
		if _age > _profile.lifetime:
			deactivate()
		elif _age > _profile.lifetime - 1.0:
			modulate.a = _profile.lifetime - _age

func _on_body_entered(body: Node) -> void:
	if not active or not _armed:
		return
	if body.is_in_group("player") and body.has_method("collect"):
		body.collect(_profile)
		deactivate()

## Placeholder loot art: a flattened ground shadow + a gently bobbing token with
## a per-kind glyph, so the five loot types read at a glance (matches the
## colored-shape placeholder language of the rest of the prototype).
class PickupArt:
	extends Node2D
	var kind := 0
	var color := Color.WHITE
	var radius := 6.0
	var _t := 0.0

	func setup(p: LootProfile) -> void:
		kind = p.kind
		color = p.color
		radius = p.radius
		_t = 0.0
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var bob := 2.0 + sin(_t * 4.0) * 1.5
		# Flattened ground shadow — drawn under a squashed transform so it stays
		# put while the token bobs above it.
		draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius * 0.95, Color(0.0, 0.0, 0.0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_token(Vector2(0.0, -bob))

	func _draw_token(c: Vector2) -> void:
		draw_circle(c, radius, color)
		draw_arc(c, radius, 0.0, TAU, 20, color.lerp(Color.WHITE, 0.5), 1.5)
		var fg := Color(1.0, 1.0, 1.0, 0.95)
		match kind:
			LootProfile.Kind.COIN:
				draw_arc(c, radius * 0.5, 0.0, TAU, 14, color.darkened(0.4), 1.5)
			LootProfile.Kind.HEALTH:
				var a := radius * 0.55
				draw_line(c + Vector2(-a, 0.0), c + Vector2(a, 0.0), fg, 2.0)
				draw_line(c + Vector2(0.0, -a), c + Vector2(0.0, a), fg, 2.0)
			LootProfile.Kind.POWER:
				var s := radius * 0.5
				draw_line(c + Vector2(-s, s * 0.4), c + Vector2(0.0, -s), fg, 2.0)
				draw_line(c + Vector2(0.0, -s), c + Vector2(s, s * 0.4), fg, 2.0)
			LootProfile.Kind.SPEED:
				for ox in [-radius * 0.28, radius * 0.32]:
					draw_line(c + Vector2(ox - radius * 0.18, -radius * 0.4),
						c + Vector2(ox + radius * 0.22, 0.0), fg, 2.0)
					draw_line(c + Vector2(ox + radius * 0.22, 0.0),
						c + Vector2(ox - radius * 0.18, radius * 0.4), fg, 2.0)
			LootProfile.Kind.INVINCIBLE:
				draw_arc(c, radius + 2.5, 0.0, TAU, 22, Color(1.0, 1.0, 1.0, 0.8), 1.5)
