class_name PropBase
extends RigidBody2D
## Loose props (barrels, crates): the real physics engine owns movement (GDD §4).
## Includes the PropImpactReporter role (§11): contact monitoring, previous-tick
## velocity cache, forwards contacts to the resolver.

@export var profile: PropProfile

# Hydrated from the profile in _ready.
var stats: PhysicsStats
var color := Color.WHITE
var radius := 10.0
var rect_size := Vector2.ZERO

var persist_id := ""

var _health: HealthComponent
var _art: PlaceholderArt
var _prev_velocity := Vector2.ZERO   # cached pre-collision velocity (§4.2 row 4)

func _ready() -> void:
	stats = profile.stats
	color = profile.color
	radius = profile.radius
	rect_size = profile.rect_size

	collision_layer = Tuning.L_PROP
	collision_mask = Tuning.L_WORLD | Tuning.L_PLAYER | Tuning.L_ENEMY | Tuning.L_PROP
	gravity_scale = 0.0
	linear_damp = stats.drag
	angular_damp = 3.0
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	if persist_id != "" and WorldState.is_destroyed(MapManager.current_map_id, persist_id):
		queue_free()
		return

	add_child(EntityKit.rect_collider(rect_size) if rect_size != Vector2.ZERO
		else EntityKit.circle_collider(radius))

	_art = PlaceholderArt.new()
	_art.color = color
	_art.radius = radius
	_art.rect_size = rect_size
	add_child(_art)

	_health = HealthComponent.new()
	_health.setup(stats.max_hp)
	_health.damaged.connect(func(_a: float, _e: ImpactEvent) -> void: _art.flash())
	add_child(_health)

	var breakable := Breakable.new()
	breakable.setup(self, stats, _health)
	add_child(breakable)

	add_child(EntityKit.make_hurtbox(radius, rect_size))

func _physics_process(_delta: float) -> void:
	_prev_velocity = linear_velocity

func _on_body_entered(body: Node) -> void:
	# Tile walls / statless statics: resolve against infinite mass.
	if body.has_method("get_stats"):
		ImpactResolver.resolve_body_pair(self, body)
	else:
		var n := -_prev_velocity.normalized()
		if n == Vector2.ZERO:
			return
		var ev := ImpactEvent.new()
		ev.body_a = self
		ev.body_b = null
		ev.normal = -n   # from prop toward the surface ≈ travel direction
		ev.contact_point = global_position
		ev.rel_velocity = _prev_velocity
		ImpactResolver.resolve(ev)

# ------------------------------------------------------ PhysicsEntity duck-type

func get_stats() -> PhysicsStats:
	return stats

func get_impact_velocity() -> Vector2:
	# Prefer the cached pre-collision velocity: by the time a contact is
	# reported the solver may already have zeroed it.
	return _prev_velocity if _prev_velocity.length() > linear_velocity.length() \
		else linear_velocity

func apply_impact_result(new_velocity: Vector2) -> void:
	linear_velocity = new_velocity
	angular_velocity += randf_range(-3.0, 3.0)   # cheap tumble
	sleeping = false

func take_impact_damage(amount: float, event: ImpactEvent) -> void:
	_health.take_damage(amount, event)
