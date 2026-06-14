extends Node2D
## Pre-instantiates DEBRIS_POOL_SIZE shards (D7). Pool exhausted ⇒ oldest
## live shard is recycled. Shards live under this autoload in global coords.

var _pool: Array[DebrisShard] = []

func _ready() -> void:
	for i in Tuning.DEBRIS_POOL_SIZE:
		var s := DebrisShard.new()
		add_child(s)
		_pool.append(s)
	EventBus.map_changed.connect(func(_id: String) -> void: reclaim_all())

func live_count() -> int:
	var n := 0
	for s in _pool:
		if s.active:
			n += 1
	return n

func spawn_burst(pos: Vector2, incoming_velocity: Vector2, payload: BreakPayload) -> void:
	if payload.debris == null:
		return
	var count := randi_range(payload.count_min, payload.count_max)
	var inherit := incoming_velocity * payload.inherit_factor
	for i in count:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var speed := randf_range(payload.eject_speed_min, payload.eject_speed_max)
		_get_shard().activate(pos + dir * 4.0, inherit + dir * speed, payload.debris)

func reclaim_all() -> void:
	for s in _pool:
		s.deactivate()

func _get_shard() -> DebrisShard:
	var oldest: DebrisShard = _pool[0]
	for s in _pool:
		if not s.active:
			return s
		if s.spawn_time < oldest.spawn_time:
			oldest = s
	return oldest   # recycle the oldest live shard
