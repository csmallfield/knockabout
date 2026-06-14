extends Node
## Content registry. Scans res://resources/profiles/ at boot; every .tres
## becomes a spawnable id (= filename without extension). Maps, spawners, and
## debug keys reference ids, never scenes — adding content is adding a file.

const PROFILE_ROOT := "res://resources/profiles"
const MOB_SCENE := "res://entities/mobs/mob.tscn"
const LOOSE_PROP_SCENE := "res://entities/props/loose_prop.tscn"
const ANCHORED_PROP_SCENE := "res://entities/props/anchored_prop.tscn"

var _profiles: Dictionary = {}   # id -> Resource

func _ready() -> void:
	_scan(PROFILE_ROOT)
	print("EntityRegistry: %d profiles loaded: %s" % [_profiles.size(), ids()])

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("EntityRegistry: cannot open %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan(path.path_join(entry))
		else:
			# Exported PCKs list converted resources as *.tres.remap.
			var file := entry.trim_suffix(".remap")
			if file.ends_with(".tres"):
				var id := file.get_basename()
				if _profiles.has(id):
					push_error("EntityRegistry: duplicate profile id '%s'" % id)
				else:
					_profiles[id] = load(path.path_join(file))
		entry = dir.get_next()
	dir.list_dir_end()

func ids() -> Array:
	var keys := _profiles.keys()
	keys.sort()
	return keys

func has_profile(id: String) -> bool:
	return _profiles.has(id)

func get_profile(id: String) -> Resource:
	if not _profiles.has(id):
		push_error("EntityRegistry: unknown profile id '%s'" % id)
		return null
	return _profiles[id]

## Instantiate the right generic scene for a profile id and hand it the
## profile. Returns null (with an error) for ids that aren't spawnable
## (weapons, debris, player).
func spawn(id: String) -> Node2D:
	var profile := get_profile(id)
	if profile is MobProfile:
		return _instance(MOB_SCENE, profile)
	if profile is PropProfile:
		var scene := LOOSE_PROP_SCENE if profile.body_type == PropProfile.BodyType.LOOSE \
			else ANCHORED_PROP_SCENE
		return _instance(scene, profile)
	push_error("EntityRegistry: profile '%s' is not spawnable" % id)
	return null

func _instance(scene_path: String, profile: Resource) -> Node2D:
	var n: Node2D = (load(scene_path) as PackedScene).instantiate()
	n.set("profile", profile)
	return n
