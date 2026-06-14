class_name AnchoredBase
extends StaticBody2D
## Anchored objects (GDD §4): no movement authority until destroyed.
## High mass + toughness make them behave like terrain that can still lose.

@export var profile: PropProfile

# Hydrated from the profile in _ready.
var stats: PhysicsStats
var color := Color.WHITE
var radius := 10.0
var rect_size := Vector2.ZERO

var persist_id := ""

var _health: HealthComponent
var _art: PlaceholderArt

func _ready() -> void:
	stats = profile.stats
	color = profile.color
	radius = profile.radius
	rect_size = profile.rect_size

	collision_layer = Tuning.L_WORLD
	collision_mask = 0

	if persist_id != "" and WorldState.is_destroyed(MapManager.current_map_id, persist_id):
		_spawn_variant_only()
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

func _spawn_variant_only() -> void:
	# Already destroyed in this session: leave only the remnant, if any.
	if stats.destroyed_variant:
		var v := stats.destroyed_variant.instantiate()
		v.position = position
		get_parent().add_child.call_deferred(v)
	queue_free()

# ------------------------------------------------------ PhysicsEntity duck-type

func get_stats() -> PhysicsStats:
	return stats

func get_impact_velocity() -> Vector2:
	return Vector2.ZERO

func apply_impact_result(_new_velocity: Vector2) -> void:
	pass   # anchored: the resolver's INF-mass path never moves us anyway

func take_impact_damage(amount: float, event: ImpactEvent) -> void:
	_health.take_damage(amount, event)
