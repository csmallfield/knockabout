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
var _buff: BuffComponent

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

# --- charge attack (D5) ---
var _charging := false
var _charge_time := 0.0
var _charge_level := -1            # -1 = base (uncharged); ≥0 indexes weapon.charge_levels
var _swing_damage_mult := 1.0      # captured from the reached tier at release
var _swing_impulse_mult := 1.0

# --- block / parry ---
var _blocking := false
var _block_start_msec := 0
var _block_shield: BlockShield

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

	_buff = BuffComponent.new()
	add_child(_buff)

	add_child(EntityKit.make_hurtbox(profile.body_radius))

	_weapon_pivot = _build_weapon()
	_weapon_pivot.rotation = facing.angle()
	add_child(_weapon_pivot)
	_roll_hitbox = _build_roll_hitbox()
	add_child(_roll_hitbox)

	# Frontal block indicator (placeholder-art language: a drawn arc).
	_block_shield = BlockShield.new()
	_block_shield.radius = profile.body_radius + 8.0
	_block_shield.arc_degrees = profile.block_arc_degrees
	_block_shield.visible = false
	add_child(_block_shield)

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
			intent = _roll_dir * lerpf(profile.roll_speed, _walk_speed(), t)
			if _roll_hitbox.monitoring:
				_check_roll_shoves()
			if _roll_timer <= 0.0:
				_roll_hitbox.set_deferred("monitoring", false)
		else:
			# --- block (held state); the rising edge opens the parry window ---
			if Input.is_action_just_pressed("block"):
				_cancel_charge()
				_block_start_msec = Time.get_ticks_msec()
			_blocking = Input.is_action_pressed("block")

			# --- charge / attack (no-op while guarding) ---
			_update_charge_input(delta)

			# --- movement, slowed by charge or block ---
			intent = input * _walk_speed() * _state_move_mult()
			if input != Vector2.ZERO:
				facing = input.normalized()   # still aim freely while charging / blocking
				_art.facing = facing

			# --- roll cancels both charge and block ---
			if Input.is_action_just_pressed("roll") and _roll_cooldown <= 0.0:
				_cancel_charge()
				_blocking = false
				_start_roll(input)
			if Input.is_action_just_pressed("interact"):
				_try_interact()
	else:
		# Launched / stunned: you can't guard or hold a charge.
		_blocking = false
		_cancel_charge()

	_motion.physics_update(intent, delta)
	_update_swing(delta)
	_update_visuals()

## Effective walk speed with the SPEED buff folded in (§6.5).
func _walk_speed() -> float:
	return profile.walk_speed * _buff.speed_mult()

## Extra move-speed scalar from the current action state (charge / block).
func _state_move_mult() -> float:
	if _blocking:
		return profile.block_move_mult
	if _charging:
		if _charge_level >= 0 and _charge_level < weapon.charge_levels.size():
			return weapon.charge_levels[_charge_level].move_mult
		return profile.charge_base_move_mult
	return 1.0

# --------------------------------------------------------------------- roll

func _start_roll(input: Vector2) -> void:
	_roll_dir = input.normalized() if input != Vector2.ZERO else facing
	_roll_timer = profile.roll_duration
	_roll_cooldown = profile.roll_cooldown
	_iframes = maxf(_iframes, profile.roll_iframes)
	_roll_hitbox.monitoring = true

func _check_roll_shoves() -> void:
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

# -------------------------------------------------------------- charge input
## Hold-to-charge, release-to-swing — but only when the weapon declares tiers.
## A weapon with no charge_levels keeps the old fire-on-press behaviour.

func _update_charge_input(delta: float) -> void:
	if _blocking:
		_cancel_charge()   # guarding suppresses the attack entirely
		return

	if weapon.charge_levels.is_empty():
		# Legacy instant swing.
		if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0:
			_release_swing(-1)
		return

	if Input.is_action_just_pressed("attack") and _attack_cooldown <= 0.0 and not _charging:
		_charging = true
		_charge_time = 0.0
		_charge_level = -1

	if _charging:
		_charge_time += delta
		_charge_level = _reached_charge_level(_charge_time)
		if Input.is_action_just_released("attack"):
			var lvl := _charge_level
			_charging = false
			_release_swing(lvl)

func _reached_charge_level(t: float) -> int:
	var lvl := -1
	for i in weapon.charge_levels.size():
		if t >= weapon.charge_levels[i].hold_time:
			lvl = i
		else:
			break
	return lvl

func _cancel_charge() -> void:
	_charging = false
	_charge_time = 0.0
	_charge_level = -1

func _charge_ratio() -> float:
	if weapon.charge_levels.is_empty():
		return 0.0
	var maxt: float = weapon.charge_levels.back().hold_time
	if maxt <= 0.0:
		return 0.0
	return clampf(_charge_time / maxt, 0.0, 1.0)

# -------------------------------------------------------------------- swing
## The weapon is a visible club on a pivot at the player's center. A swing
## sweeps it across weapon.arc_degrees over active_frames; the blade Area2D is
## the contact volume. The reached charge tier scales damage + impulse.

func _release_swing(level: int) -> void:
	if level >= 0 and level < weapon.charge_levels.size():
		var cl: ChargeLevel = weapon.charge_levels[level]
		_swing_damage_mult = cl.damage_mult
		_swing_impulse_mult = cl.impulse_mult
	else:
		_swing_damage_mult = 1.0
		_swing_impulse_mult = 1.0
	_start_swing()

func _start_swing() -> void:
	var cd := weapon.cooldown
	if profile.speed_attack_scaling and _buff.is_active(LootProfile.Kind.SPEED):
		cd /= maxf(_buff.speed_mult(), 0.001)
	_attack_cooldown = cd
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
		# At rest the club tracks facing — but while charging it cocks back,
		# winding further the longer you hold (the telegraph).
		var target := facing.angle()
		if _charging:
			target = facing.angle() - _swing_sign * deg_to_rad(weapon.arc_degrees) * 0.5 * _charge_ratio()
		_weapon_pivot.rotation = lerp_angle(
			_weapon_pivot.rotation, target, minf(1.0, 14.0 * delta))
		return
	_swing_frames_left -= 1
	var p := 1.0 - float(_swing_frames_left) / float(_swing_total_frames)
	var half := deg_to_rad(weapon.arc_degrees) * 0.5
	_weapon_pivot.rotation = facing.angle() + _swing_sign * lerpf(-half, half, p)
	for area in _swing_hitbox.get_overlapping_areas():
		var entity := EntityKit.hurtbox_entity(area)
		if entity == null or entity == self or _swing_hits.has(entity.get_instance_id()):
			continue
		_swing_hits[entity.get_instance_id()] = true
		var dir: Vector2 = (entity.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = facing
		if weapon.knockback_mode == WeaponProfile.KnockbackMode.TANGENTIAL:
			dir = dir.rotated(_swing_sign * PI * 0.5)
		var inherit := maxf(get_impact_velocity().dot(dir), 0.0)
		var impulse := (weapon.impulse + weapon.velocity_inherit * inherit * stats.mass) * _swing_impulse_mult
		ImpactResolver.resolve_synthetic(self, entity, dir, impulse,
			weapon.flat_damage * _swing_damage_mult, entity.global_position, _swing_hits.size())
	if _swing_frames_left <= 0:
		_swing_hitbox.set_deferred("monitoring", false)

func is_attacking() -> bool:
	return _swing_frames_left > 0

func _build_weapon() -> Node2D:
	var pivot := Node2D.new()
	pivot.name = "WeaponPivot"
	var tip := weapon.range_px
	var base := maxf(tip - weapon.blade_length, 8.0)

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

## A drawn frontal guard arc, shown while blocking; brighter in the parry window.
class BlockShield:
	extends Node2D
	var radius := 18.0
	var arc_degrees := 150.0
	var facing := Vector2.DOWN
	var parry := false

	func _draw() -> void:
		var a := facing.angle()
		var half := deg_to_rad(arc_degrees) * 0.5
		var col := Color(1.0, 0.95, 0.5, 0.95) if parry else Color(0.5, 0.8, 1.0, 0.8)
		draw_arc(Vector2.ZERO, radius, a - half, a + half, 28, col, 3.0)

# --------------------------------------------------------------- block / parry

func _is_parrying() -> bool:
	return _blocking and (Time.get_ticks_msec() - _block_start_msec) <= int(profile.parry_window * 1000.0)

## Frontal check from the event (accurate: event.normal points attacker→player).
func _facing_attacker(event: ImpactEvent) -> bool:
	if event == null:
		return true
	var to_attacker := Vector2.ZERO
	if event.body_a is Node2D and is_instance_valid(event.body_a):
		to_attacker = (event.body_a as Node2D).global_position - global_position
	else:
		to_attacker = -event.normal
	if to_attacker.length() < 0.001:
		return true
	return facing.dot(to_attacker.normalized()) >= cos(deg_to_rad(profile.block_arc_degrees * 0.5))

## Frontal check from knockback only (apply_impact_result has no event — the
## knockback delta points away from the attacker, so negate it for the source).
func _facing_attacker_vel(new_velocity: Vector2) -> bool:
	var delta := new_velocity - get_impact_velocity()
	if delta.length() < 1.0:
		return true
	return facing.dot(-delta.normalized()) >= cos(deg_to_rad(profile.block_arc_degrees * 0.5))

## Reflect the attack's damage + impulse back onto the attacker. Routed through
## the resolver (for the juice + scoring/meter credit) with bypass_cooldown set —
## see impact_resolver._pair_ok: a same-frame reflect shares the pair key with
## the hit that triggered it and would otherwise be swallowed by PAIR_COOLDOWN.
func _do_parry(amount: float, event: ImpactEvent) -> void:
	add_trauma(0.35)
	var attacker := event.body_a
	if attacker == null or not is_instance_valid(attacker) or not attacker.has_method("take_impact_damage"):
		return
	var dir := ((attacker as Node2D).global_position - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = facing
	var reflect_dmg := amount * profile.parry_reflect_damage_mult
	var reflect_imp: float = profile.parry_reflect_impulse
	if event.synthetic and event.synthetic_impulse > 0.0:
		reflect_imp = event.synthetic_impulse * profile.parry_reflect_impulse_mult
	ImpactResolver.resolve_synthetic(self, attacker, dir, reflect_imp, reflect_dmg,
		(attacker as Node2D).global_position, 0, true)

# --------------------------------------------------------------- loot / buffs

func collect(loot: LootProfile) -> void:
	match loot.kind:
		LootProfile.Kind.COIN:
			ScoreManager.add_coins(int(loot.amount))
		LootProfile.Kind.HEALTH:
			heal(loot.amount)
		LootProfile.Kind.POWER:
			ScoreManager.add_power_levels(loot.power_levels)
		LootProfile.Kind.SPEED:
			_buff.apply(LootProfile.Kind.SPEED, loot.amount, {"speed_mult": loot.speed_mult})
		LootProfile.Kind.INVINCIBLE:
			_buff.apply(LootProfile.Kind.INVINCIBLE, loot.amount)

func heal(amount: float) -> void:
	_health.heal(amount)
	EventBus.player_hp_changed.emit(_health.hp, _health.max_hp)

## Visual priority: INVINCIBLE > i-frames > block/parry > charge > normal.
func _update_visuals() -> void:
	_block_shield.visible = _blocking
	if _blocking:
		_block_shield.facing = facing
		_block_shield.parry = _is_parrying()
		_block_shield.queue_redraw()

	if _buff.is_active(LootProfile.Kind.INVINCIBLE):
		_art.modulate = Color(1.0, 0.9, 0.35)
		_art.modulate.a = 0.55 if (int(Time.get_ticks_msec() / 60.0) % 2 == 0) else 1.0
		return
	if _iframes > 0.0:
		_art.modulate = Color.WHITE
		_art.modulate.a = 0.5 if (int(_iframes * 20.0) % 2 == 0) else 1.0
		return
	var base := Color.WHITE
	if _blocking:
		base = Color(0.7, 0.95, 1.0) if _is_parrying() else Color(0.6, 0.75, 0.95)
	elif _charging:
		base = Color.WHITE.lerp(Color(1.0, 0.75, 0.3), _charge_ratio())
	_art.modulate = base
	_art.modulate.a = 1.0

# ---------------------------------------------------------- damage loop (D6)

func _on_damaged(_amount: float, _event: ImpactEvent) -> void:
	_art.flash()
	_iframes = maxf(_iframes, profile.hit_iframes)
	_cancel_charge()   # a clean hit drops the wind-up
	EventBus.player_hp_changed.emit(_health.hp, _health.max_hp)
	EventBus.player_damaged.emit(_amount)

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
	# INVINCIBLE blocks launch/knockback for its duration (8A).
	if _buff.is_active(LootProfile.Kind.INVINCIBLE):
		return
	# Block (frontal) softens knockback; a timed parry negates it entirely.
	if _blocking and _facing_attacker_vel(new_velocity):
		if _is_parrying():
			return
		var cur := get_impact_velocity()
		new_velocity = cur + (new_velocity - cur) * profile.block_knockback_mult
	_motion.apply_impact_result(new_velocity)

func take_impact_damage(amount: float, event: ImpactEvent) -> void:
	# A frontal guard is checked first so a well-timed parry always reflects,
	# even through residual i-frames.
	if _blocking and _facing_attacker(event):
		if _is_parrying():
			_do_parry(amount, event)
			return
		if _iframes > 0.0 or _buff.is_active(LootProfile.Kind.INVINCIBLE):
			return
		_health.take_damage(amount * profile.block_damage_mult, event)
		return
	if _iframes > 0.0 or _buff.is_active(LootProfile.Kind.INVINCIBLE):
		return
	_health.take_damage(amount, event)

# ------------------------------------------------------------- camera shake

func add_trauma(amount: float) -> void:
	_shake_trauma = minf(_shake_trauma + amount, 1.0)

func _update_camera_shake(delta: float) -> void:
	_shake_trauma = maxf(_shake_trauma - delta * 1.8, 0.0)
	var shake := _shake_trauma * _shake_trauma
	_camera.offset = Vector2(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 8.0

func set_camera_limits(bounds: Rect2) -> void:
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.reset_smoothing()