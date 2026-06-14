extends Node
## Session persistence of destruction (D3). Plain nested Dictionary,
## deliberately JSON-serializable — the future save system writes this
## struct to disk and adds a player block. Mobs are NOT persisted.

var _maps := {}   # { map_id: { persist_id: { "destroyed": bool, ... } } }

func mark_destroyed(map_id: String, persist_id: String) -> void:
	_entry(map_id, persist_id)["destroyed"] = true

func is_destroyed(map_id: String, persist_id: String) -> bool:
	return _maps.get(map_id, {}).get(persist_id, {}).get("destroyed", false)

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
