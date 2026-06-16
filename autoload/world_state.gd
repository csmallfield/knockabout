extends Node
## Session persistence of destruction (D3). Plain nested Dictionary,
## deliberately JSON-serializable — the future save system writes this
## struct to disk and adds a player block. Mobs are NOT persisted.
##
## Coins live here too (§3): they persist across map changes / death, unlike
## score/power/meter, which now ALSO persist across rooms but are run-local
## (ScoreManager owns them and clears them on a new run).
##
## Room-clear flags live here too: once a room is cleared its doors stay open
## and its mob spawners stay silent on re-entry (backtracking model B). Wiped
## by reset_run() at the start of a fresh run.

var _maps := {}            # { map_id: { persist_id: { "destroyed": bool, ... } } }
var _rooms_cleared := {}   # { map_id: true } — set once a room is cleared
var coins := 0             # persistent coin total (survives map change + respawn)

# ---------------------------------------------------------------- destruction

func mark_destroyed(map_id: String, persist_id: String) -> void:
	_entry(map_id, persist_id)["destroyed"] = true

func is_destroyed(map_id: String, persist_id: String) -> bool:
	return _maps.get(map_id, {}).get(persist_id, {}).get("destroyed", false)

# ---------------------------------------------------------------- room clears

func mark_room_cleared(map_id: String) -> void:
	_rooms_cleared[map_id] = true

func is_room_cleared(map_id: String) -> bool:
	return _rooms_cleared.get(map_id, false)

# ----------------------------------------------------------------------- coins

func add_coins(n: int) -> void:
	coins += n

func get_coins() -> int:
	return coins

# ------------------------------------------------------------------ run reset

## Start-of-run wipe: destruction, room clears, and coins all reset. Score /
## power are reset by ScoreManager.reset_run() alongside this. (Normal app
## launch starts clean already — this is for the in-session restart.)
func reset_run() -> void:
	_maps.clear()
	_rooms_cleared.clear()
	coins = 0

# --------------------------------------------------------------------- generic

## Generic state for later needs (chests, switches).
func set_state(map_id: String, persist_id: String, data: Dictionary) -> void:
	_entry(map_id, persist_id).merge(data, true)

func get_state(map_id: String, persist_id: String) -> Dictionary:
	return _maps.get(map_id, {}).get(persist_id, {})

func _entry(map_id: String, persist_id: String) -> Dictionary:
	if not _maps.has(map_id):
		_maps[map_id] = {}
	if not _maps[map_id].has(persist_id):
		_maps[map_id][persist_id] = {}
	return _maps[map_id][persist_id]
