class_name Player
extends CharacterBody2D
## The player is an actor like any other (GDD §4.1): same stats, same resolver.

@export var profile: PlayerProfile

# Hydrated from the profile in _ready.
var stats: PhysicsStats
var weapon: WeaponProfile

var facing := Vector2.DOWN
var persist_id := ""   # unused; present for duck-type uniformity

var _motion: BallisticMotion
var _health: HealthComponent
var _art: PlaceholderArt
var _camera: Camera2D

var _roll_timer := 0.0
var _roll_cooldown := 0.0
var _roll_dir := Vector2.DOWN
var _iframes := 0.0
var _attack_cooldown := 0.0
var _weapon_pivot: Node2D
var _swing_hitbox: Area2D
var _swing_frames_left := 0
var _swing_total_frames := 6
var _swing_sign := 1.0
var _swing_hits := {}
var _roll_hitbox: Area2D
var _shake_trauma := 0.0

func _ready() -> void:
	stats = profile.stats
	weapon = profile.weapon

	add_to_group("player")
	add_to_group("ballistic")
	collision_layer = Tuning.L_PLAYER
	collision_mask = Tuning.L_WORLD | Tuning.L_ENEMY | Tuning.L_PROP
	add_child(EntityKit.circle_collider(profile.body_radius))

	_art = PlaceholderArt.new()
	_art.color = profile.color
	_art.radius = profile.body_radius
	_art.show_facing = true
	add_child(_art)

	_motion = BallisticMotion.new()
	_motion.setup(self, stats)
	_motion.stun_time = Tuning.STUN_TIME_PLAYER
	_motion.launched.connect(func(_v: Vector2) -> void: _art.squash())
	add_child(_motion)

	_health = HealthComponent.new()
	_health.setup(stats.max_hp)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	add_child(_health)

	add_child(EntityKit.make_hurtbox(profile.body_radius))

	_weapon_pivot = _build_weapon()
	_weapon_pivot.rotation = facing.angle()
	add_child(_weapon_pivot)
	_roll_hitbox = _build_roll_hitbox()
	add_child(_roll_hitbox)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()

	EventBus.player_hp_changed.emit(_health.hp, _health.max_hp)

# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	_roll_cooldown = maxf(_roll_cooldown - delta, 0.0)
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_iframes = maxf(_iframes - delta, 0.0)
	_update_camera_shake(delta)

	var intent := Vector2.ZERO
	if _motion.is_controllable():
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if _roll_timer > 0.0:
			_roll_timer -= delta
			var t := 1.0 - _roll_timer / profile.roll_duration
			intent = _roll_dir * lerpf(profile.roll_speed, profile.walk_speed, t)
			if _roll_hitbox.monitoring:
				_check_roll_shoves()
			if _roll_timer <= 0.0:
				_roll_hitbox.set_deferred("monitoring", false)
		else:
			intent = input * profile.walk_speed
			if input != Vector2.ZERO:
				facing = input.normalized()
				_art.facing = facing
			if Input.is_action_just_pressed("roll") and _roll_cooldown <= 0.0:
				_start_roll(input)
		if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
			_start_swing()
		if Input.is_action_just_pressed("interact"):
			_try_interact()

	_motion.physics_update(intent, delta)
	_update_swing(delta)
	_art.modulate.a = 0.5 if (_iframes > 0.0 and int(_iframes * 20.0) % 2 == 0) else 1.0

# --------------------------------------------------------------------- roll

func _start_roll(input: Vector2) -> void:
	_roll_dir = input.normalized() if input != Vector2.ZERO else facing
	_roll_timer = profile.roll_duration
	_roll_cooldown = profile.roll_cooldown
	_iframes = maxf(_iframes, profile.roll_iframes)
	_roll_hitbox.monitoring = true

func _check_roll_shoves() -> void:
	# The roll is itself a physics event (§6.2): live-momentum body pair.
	for area in _roll_hitbox.get_overlapping_areas():
		var entity := EntityKit.hurtbox_entity(area)
		if entity and entity != self:
			ImpactResolver.resolve_body_pair(self, entity)

func _build_roll_hitbox() -> Area2D:
	var area := Area2D.new()
	area.name = "RollHitbox"
	area.collision_layer = Tuning.L_HITBOX
	area.collision_mask = Tuning.L_HURTBOX
	area.monitoring = false
	area.add_child(EntityKit.circle_collider(14.0))
	return area

# -------------------------------------------------------------------- swing
## The weapon is a visible 32 px club on a pivot at the player's center.
## A swing sweeps the pivot across weapon.arc_degrees over active_frames;
## the blade's Area2D is the actual contact volume. Sweep direction
## alternates each swing.

func _start_swing() -> void:
	_attack_cooldown = weapon.cooldown
	_swing_frames_left = weapon.active_frames
	_swing_total_frames = weapon.active_frames
	_swing_hits.clear()
	if weapon.swing_pattern == WeaponProfile.SwingPattern.ALTERNATE:
		_swing_sign = -_swing_sign
	var half := deg_to_rad(weapon.arc_degrees) * 0.5
	_weapon_pivot.rotation = facing.angle() - _swing_sign * half
	_swing_hitbox.monitoring = true

func _update_swing(delta: float) -> void:
	if _swing_frames_left <= 0:
		# At rest the club tracks the facing direction.
		_weapon_pivot.rotation = lerp_angle(
			_weapon_pivot.rotation, facing.angle(), minf(1.0, 14.0 * delta))
		return
	_swing_frames_left -= 1
	var p := 1.0 - float(_swing_frames_left) / float(_swing_total_frames)
	var half := deg_to_rad(weapon.arc_degrees) * 0.5
	_weapon_pivot.rotation = facing.angle() + _swing_sign * lerpf(-half, half, p)
	for area in _swing_hitbox.get_overlapping_areas():
		var entity := EntityKit.hurtbox_entity(area)
		if entity == null or entity == self or _swing_hits.has(entity.get_instance_id()):
			continue
		_swing_hits[entity.get_instance_id()] = true   # swing-id dedup (§6.1)
		var dir: Vector2 = (entity.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = facing
		if weapon.knockback_mode == WeaponProfile.KnockbackMode.TANGENTIAL:
			dir = dir.rotated(_swing_sign * PI * 0.5)   # along the sweep at contact
		# velocity_inherit: moving into the swing hits harder (§6.1).
		var inherit := maxf(get_impact_velocity().dot(dir), 0.0)
		var impulse := weapon.impulse + weapon.velocity_inherit * inherit * stats.mass
		ImpactResolver.resolve_synthetic(self, entity, dir, impulse,
			weapon.flat_damage, entity.global_position)
	if _swing_frames_left <= 0:
		_swing_hitbox.set_deferred("monitoring", false)

func _build_weapon() -> Node2D:
	var pivot := Node2D.new()
	pivot.name = "WeaponPivot"
	var tip := weapon.range_px
	var base := maxf(tip - weapon.blade_length, 8.0)   # blade never inside the body

	var art := WeaponArt.new()
	art.blade_base = base
	art.blade_tip = tip
	art.color = weapon.color
	art.shaft_width = weapon.shaft_width
	art.head_radius = weapon.head_radius
	pivot.add_child(art)

	_swing_hitbox = Area2D.new()
	_swing_hitbox.name = "SwingHitbox"
	_swing_hitbox.collision_layer = Tuning.L_HITBOX
	_swing_hitbox.collision_mask = Tuning.L_HURTBOX
	_swing_hitbox.monitoring = false
	var cs := EntityKit.rect_collider(Vector2(tip - base + 6.0, 10.0))
	cs.position = Vector2((base + tip) * 0.5, 0.0)
	_swing_hitbox.add_child(cs)
	pivot.add_child(_swing_hitbox)
	return pivot

class WeaponArt:
	extends Node2D
	## Placeholder weapon: shaft + round head at the tip, styled by the profile.
	var blade_base := 12.0
	var blade_tip := 44.0
	var color := Color(0.5, 0.36, 0.2)
	var shaft_width := 5.0
	var head_radius := 5.0

	func _draw() -> void:
		draw_line(Vector2(blade_base, 0), Vector2(blade_tip - head_radius + 1.0, 0),
			color, shaft_width)
		draw_circle(Vector2(blade_tip - head_radius + 2.0, 0), head_radius,
			color.darkened(0.2))

# ---------------------------------------------------------- damage loop (D6)

func _on_damaged(_amount: float, _event: ImpactEvent) -> void:
	_art.flash()
	_iframes = maxf(_iframes, profile.hit_iframes)
	EventBus.player_hp_changed.emit(_health.hp, _health.max_hp)

func _on_died(_event: ImpactEvent) -> void:
	MapManager.respawn_player()

func heal_full() -> void:
	_health.heal_full()
	EventBus.player_hp_changed.emit(_health.hp, _health.max_hp)

# --------------------------------------------------------------- interaction

func _try_interact() -> void:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	params.shape = shape
	params.transform = Transform2D(0.0, global_position + facing * 12.0)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = Tuning.L_INTERACT
	for hit in space.intersect_shape(params, 4):
		var area: Node = hit["collider"]
		if area.has_method("trigger"):
			area.trigger(self)
			return

# ------------------------------------------------------ PhysicsEntity duck-type

func is_ballistic() -> bool:
	return _motion.state == BallisticMotion.State.BALLISTIC

func get_stats() -> PhysicsStats:
	return stats

func get_impact_velocity() -> Vector2:
	return _motion.current_velocity()

func apply_impact_result(new_velocity: Vector2) -> void:
	# I-frames block damage only — knockback/launch still applies (§6.3).
	_motion.apply_impact_result(new_velocity)

func take_impact_damage(amount: float, event: ImpactEvent) -> void:
	if _iframes > 0.0:
		return
	_health.take_damage(amount, event)

# ------------------------------------------------------------- camera shake

func add_trauma(amount: float) -> void:
	_shake_trauma = minf(_shake_trauma + amount, 1.0)

func _update_camera_shake(delta: float) -> void:
	_shake_trauma = maxf(_shake_trauma - delta * 1.8, 0.0)
	var shake := _shake_trauma * _shake_trauma   # trauma-based (§12)
	_camera.offset = Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 8.0

func set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.reset_smoothing()
