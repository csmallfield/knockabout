extends Node
## Attack-token pool (the Arkham/Mordor trick): only a few mobs may be mid-attack
## at once; the rest circle and wait their turn, so a group reads as deliberate
## rather than a synchronized dogpile. Single global pool — one player target.
## Cap lives in Tuning (it's a global rule, not per-mob content).

var _attackers: Dictionary = {}   # instance_id -> true

func _ready() -> void:
	# Maps are torn down wholesale on transition/respawn; drop stale holders.
	EventBus.map_changed.connect(func(_id: String) -> void: _attackers.clear())

## Grant a token if a slot is free (idempotent for current holders).
func request_token(mob: Node) -> bool:
	_purge()
	var id := mob.get_instance_id()
	if _attackers.has(id):
		return true
	if _attackers.size() >= Tuning.MAX_SIMULTANEOUS_ATTACKERS:
		return false
	_attackers[id] = true
	return true

func release_token(mob: Node) -> void:
	if mob:
		_attackers.erase(mob.get_instance_id())

func active_count() -> int:
	_purge()
	return _attackers.size()

func _purge() -> void:
	for id in _attackers.keys():
		if not is_instance_valid(instance_from_id(id)):
			_attackers.erase(id)
