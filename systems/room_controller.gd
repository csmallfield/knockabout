class_name RoomController
extends Node
## The "clear the room to open the doors" brain, one per map. Modelled on the
## other pure-listener autoloads (CombatDirector, ScoreManager) but lives INSIDE
## the map so it's torn down with it. It never moves bodies or deals damage — it
## counts mob deaths and flips gates.
##
## Counting, not polling: the map registers its expected mob total SYNCHRONOUSLY
## while loading (MobSpawner spawns are deferred, so the live "mobs" group is
## empty at that point — polling it would read "cleared" instantly). We tally
## EventBus.entity_died for mobs and compare against the declared total. Every
## mob death path routes through HealthComponent.died → Breakable → entity_died,
## so the count is reliable. (Debug F6 is routed through lethal damage for the
## same reason — see dev.gd.)
##
## Authored as a node in each room scene. It joins the "room_controller" group in
## _enter_tree (which runs before any sibling's _ready), so gates and mob
## spawners can find and register with it during their own _ready. MapBase then
## calls finalize() in its _ready (after all children are ready).
##
## Backtracking model B: a cleared room persists its state in WorldState; on
## re-entry its spawners stay silent (expected == 0) and gates start open.

var is_final := false   ## set by the owning map; clearing this room wins the run

var _gates: Array[Gate] = []
var _expected := 0
var _killed := 0
var _cleared := false
var _armed := false     ## true once we've committed to gating this room
var _map_id := ""

func _enter_tree() -> void:
	add_to_group("room_controller")

## Called from Gate._ready — register a door so we can lock/open it.
func register_gate(g: Gate) -> void:
	_gates.append(g)

## Called from MobSpawner._ready — declare how many mobs this room expects.
## Synchronous, so the total is correct before any deferred spawn lands.
func register_expected(n: int) -> void:
	_expected += maxi(n, 0)

## Called by MapBase after the authored nodes have registered. Decides the
## room's starting state.
func finalize(map_id: String) -> void:
	_map_id = map_id
	# Not a run room (no gated doors authored): stay completely inert so legacy
	# maps and free-roam scenes behave exactly as before.
	if _gates.is_empty():
		return

	_armed = true
	if WorldState.is_room_cleared(_map_id) or _expected <= 0:
		# Already beaten this run, or a deliberately empty room: doors open.
		_clear(false)
	else:
		# Gates are already locked from their own _ready; just start counting.
		EventBus.entity_died.connect(_on_entity_died)

## Debug / failsafe (dev.gd F10): force the current room open.
func force_clear() -> void:
	if _armed and not _cleared:
		_clear(true)

func is_cleared() -> bool:
	return _cleared

# ----------------------------------------------------------------- internals

func _on_entity_died(entity: Node, _stats: PhysicsStats, _map_id_in: String) -> void:
	if _cleared:
		return
	if not _is_mob_profile(entity):
		return   # props/trees/barrels fire entity_died too — they don't count
	_killed += 1
	if _killed >= _expected:
		_clear(true)

func _clear(fresh: bool) -> void:
	if _cleared:
		return
	_cleared = true
	WorldState.mark_room_cleared(_map_id)
	for g in _gates:
		if is_instance_valid(g):
			g.open(fresh)
	# fresh == a clear that just happened in play (vs. a room that was already
	# cleared on entry). Only a fresh clear announces itself / can win the run.
	if fresh:
		EventBus.room_cleared.emit(_map_id)
		if is_final:
			EventBus.run_completed.emit()

func _is_mob_profile(entity: Node) -> bool:
	if entity == null:
		return false
	return entity.get("profile") is MobProfile
