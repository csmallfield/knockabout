class_name DebrisShard
extends RigidBody2D
## Pooled debris (D7). Full physics citizen: damages what it hits through the
## standard prop→anything path. Breaking despawns — hard recursion stop (§8.1).

var stats := PhysicsStats.new()
var persist_id := ""
var active := false
var spawn_time := 0.0

var _art: PlaceholderArt
var _shape: CollisionShape2D
var _hurt: Area2D
var _prev_velocity := Vector2.ZERO
var _hp := 5.0

func _ready() -> void:
	collision_layer = Tuning.L_PROP
	# Debris↔debris (4↔4) is ON by default; first knob to turn per §10/§17.
	collision_mask = Tuning.L_WORLD | Tuning.L_PLAYER | Tuning.L_ENEMY | Tuning.L_PROP
	gravity_scale = 0.0
	angular_damp = 2.0
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	stats.toughness = 0.0
	stats.restitution = 0.5
	stats.drag = 1.5
	stats.breakable = false

	_shape = EntityKit.circle_collider(3.0)
	add_child(_shape)
	_art = PlaceholderArt.new()
	_art.color = Color(0.6, 0.55, 0.45)
	add_child(_art)
	_hurt = EntityKit.make_hurtbox(3.0)
	add_child(_hurt)
	deactivate()

func activate(pos: Vector2, vel: Vector2, debris: DebrisProfile) -> void:
	stats.mass = debris.mass
	stats.max_hp = debris.hp
	mass = debris.mass
	_hp = debris.hp
	linear_damp = stats.drag
	(_shape.shape as CircleShape2D).radius = debris.radius
	_art.radius = debris.radius
	_art.color = debris.color
	_art.queue_redraw()
	global_position = pos
	linear_velocity = vel
	angular_velocity = randf_range(-8.0, 8.0)
	active = true
	spawn_time = Time.get_ticks_msec() / 1000.0
	visible = true
	modulate.a = 1.0
	freeze = false
	_shape.set_deferred("disabled", false)
	sleeping = false

func deactivate() -> void:
	active = false
	visible = false
	freeze = true
	linear_velocity = Vector2.ZERO
	if _shape:
		_shape.set_deferred("disabled", true)

func _physics_process(_delta: float) -> void:
	if not active:
		return
	_prev_velocity = linear_velocity
	var age := Time.get_ticks_msec() / 1000.0 - spawn_time
	if age > Tuning.DEBRIS_LIFETIME:
		deactivate()
	elif age > Tuning.DEBRIS_LIFETIME - 1.0:
		modulate.a = Tuning.DEBRIS_LIFETIME - age   # fade-out second

func _on_body_entered(body: Node) -> void:
	if not active:
		return
	if body.has_method("get_stats"):
		ImpactResolver.resolve_body_pair(self, body)
	# Shards don't bother reporting wall hits — engine bounce is enough juice.

# ------------------------------------------------------ PhysicsEntity duck-type

func get_stats() -> PhysicsStats:
	return stats

func get_impact_velocity() -> Vector2:
	return _prev_velocity if _prev_velocity.length() > linear_velocity.length() \
		else linear_velocity

func apply_impact_result(new_velocity: Vector2) -> void:
	linear_velocity = new_velocity
	sleeping = false

func take_impact_damage(amount: float, _event: ImpactEvent) -> void:
	_hp -= amount
	if _hp <= 0.0:
		deactivate()   # instant despawn on lethal damage; no sub-debris
