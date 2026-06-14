class_name MobBase
extends CharacterBody2D
## One shared structure for all three mobs (GDD §7); behavior differences
## come from data. AI: IDLE → CHASE → CONTACT_ATTACK, straight-line pursuit.
## Physics states (BALLISTIC/STUNNED) preempt AI entirely.

@export var profile: MobProfile

# Hydrated from the profile in _ready; the rest of the file is profile-agnostic.
var stats: PhysicsStats
var color := Color.WHITE
var radius := 10.0
var walk_speed := 110.0
var contact_damage := 6.0
var contact_impulse := 6000.0
var contact_cooldown := 0.8
var aggro_radius := 280.0

var persist_id := ""   # mobs are not persisted (D3); present for uniformity

var _motion: BallisticMotion
var _health: HealthComponent
var _art: PlaceholderArt
var _attack_timer := 0.0
var _contact_zone: Area2D
var _hp_bar: MiniHealthBar

func _ready() -> void:
	stats = profile.stats
	color = profile.color
	radius = profile.radius
	walk_speed = profile.walk_speed
	contact_damage = profile.contact_damage
	contact_impulse = profile.contact_impulse
	contact_cooldown = profile.contact_cooldown
	aggro_radius = profile.aggro_radius

	add_to_group("mobs")
	collision_layer = Tuning.L_ENEMY
	collision_mask = Tuning.L_WORLD | Tuning.L_PLAYER | Tuning.L_ENEMY | Tuning.L_PROP
	add_child(EntityKit.circle_collider(radius))

	_art = PlaceholderArt.new()
	_art.color = color
	_art.radius = radius
	_art.show_facing = true
	add_child(_art)

	_motion = BallisticMotion.new()
	_motion.setup(self, stats)
	_motion.launched.connect(func(_v: Vector2) -> void:
		add_to_group("ballistic")
		_art.squash())
	_motion.landed.connect(func() -> void: remove_from_group("ballistic"))
	add_child(_motion)

	_health = HealthComponent.new()
	_health.setup(stats.max_hp)
	_health.damaged.connect(func(_a: float, _e: ImpactEvent) -> void: _art.flash())
	add_child(_health)

	# Engagement HP bar: hidden until first damage taken.
	_hp_bar = MiniHealthBar.new()
	_hp_bar.width = clampf(radius * 2.2, 18.0, 32.0)
	_hp_bar.position = Vector2(0.0, -(radius + 9.0))
	_hp_bar.visible = false
	add_child(_hp_bar)
	_health.damaged.connect(func(_a: float, _e: ImpactEvent) -> void:
		_hp_bar.visible = true
		_hp_bar.set_ratio(_health.hp / _health.max_hp))

	var breakable := Breakable.new()
	breakable.setup(self, stats, _health)
	add_child(breakable)

	add_child(EntityKit.make_hurtbox(radius))

	# Contact-attack zone: slightly larger than the body (§4.2 row 6).
	_contact_zone = Area2D.new()
	_contact_zone.collision_layer = Tuning.L_HITBOX
	_contact_zone.collision_mask = Tuning.L_HURTBOX
	_contact_zone.add_child(EntityKit.circle_collider(radius + 6.0))
	add_child(_contact_zone)

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var intent := Vector2.ZERO

	if _motion.is_controllable():
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			var to_player := player.global_position - global_position
			if to_player.length() <= aggro_radius:
				intent = to_player.normalized() * walk_speed
				_art.facing = to_player.normalized()
			if _attack_timer <= 0.0:
				_try_contact_attack(player)
		# Stun tint
		_art.modulate = Color.WHITE
	else:
		_art.modulate = Color(0.8, 0.8, 1.0) if _motion.state == BallisticMotion.State.STUNNED else Color.WHITE

	_motion.physics_update(intent, delta)

func _try_contact_attack(player: Node2D) -> void:
	for area in _contact_zone.get_overlapping_areas():
		if EntityKit.hurtbox_entity(area) == player:
			_attack_timer = contact_cooldown
			var dir := (player.global_position - global_position).normalized()
			ImpactResolver.resolve_synthetic(self, player, dir,
				contact_impulse, contact_damage, player.global_position)
			return

# ------------------------------------------------------ PhysicsEntity duck-type

func is_ballistic() -> bool:
	return _motion.state == BallisticMotion.State.BALLISTIC

func get_stats() -> PhysicsStats:
	return stats

func get_impact_velocity() -> Vector2:
	return _motion.current_velocity()

func apply_impact_result(new_velocity: Vector2) -> void:
	_motion.apply_impact_result(new_velocity)

func take_impact_damage(amount: float, event: ImpactEvent) -> void:
	_health.take_damage(amount, event)
