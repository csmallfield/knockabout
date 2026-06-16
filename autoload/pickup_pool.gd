extends Node2D
## Pre-instantiates PICKUP_POOL_SIZE pickups (mirrors DebrisPool, §6.2). Pool
## exhausted ⇒ oldest live pickup is recycled. reclaim_all() on map change.
## Pickups live under this autoload in global coords.

var _pool: Array[Pickup] = []

func _ready() -> void:
	for i in Tuning.PICKUP_POOL_SIZE:
		var p := Pickup.new()
		add_child(p)
		_pool.append(p)
	EventBus.map_changed.connect(func(_id: String) -> void: reclaim_all())

func spawn(pos: Vector2, vel: Vector2, profile: LootProfile) -> void:
	if profile == null:
		return
	_get_pickup().activate(pos, vel, profile)

func live_count() -> int:
	var n := 0
	for p in _pool:
		if p.active:
			n += 1
	return n

func reclaim_all() -> void:
	for p in _pool:
		p.deactivate()

func _get_pickup() -> Pickup:
	var oldest: Pickup = _pool[0]
	for p in _pool:
		if not p.active:
			return p
		if p.spawn_time < oldest.spawn_time:
			oldest = p
	return oldest   # recycle the oldest live pickup
