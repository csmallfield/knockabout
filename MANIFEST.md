# Knockabout — Room-Clear Run (drop-in)

Turns the free-roam prototype into a 10-room run: each room seals its doors on
entry and opens them only when every enemy is defeated; clearing the final room
(room_10) wins. Identical layout every run, hand-authored, backtracking allowed.

Unzip over `res://`, preserving paths. Nothing else to configure — **no
`project.godot` changes**: there are no new autoloads (the `RoomController` is a
per-map node, not a singleton), and no new collision layers (the LOOT layer you
already added is reused, nothing new). `class_name` globals (`RoomController`,
`Gate`) register automatically on first scan.

---

## NEW files (purely additive)

| File | What it is |
|---|---|
| `systems/room_controller.gd` | `class_name RoomController`. One per map. Counts mob deaths (via `EventBus.entity_died`, filtered to `MobProfile`) against the total the map declared, opens all gates + marks the room cleared in `WorldState` when the count is met, and fires `run_completed` on the final room. Inert if the map authored no gates (so legacy maps are untouched). |
| `maps/gate.gd` | `class_name Gate`. The visible lockable door: an `Area2D` trigger (fires the transition only while open) + a child `StaticBody2D` on `L_WORLD` that physically seals the gap while locked + a drawn placeholder bar (iron when shut, retracts/greens when open). Builds its own collision shapes — no external helper dependency. |
| `maps/room_01.gd` … `room_10.gd` | The ten room scripts (`extends MapBase`). |
| `maps/room_01.tscn` … `room_10.tscn` | The ten room scenes (script + `map_id`). `room_10` sets `is_final = true` in its **script** (`room_10.gd`), read by `MapBase` after `_build()` — the scene file no longer carries it, so a scene-file quirk can't disarm the win condition. |
| `ui/run_overlay.gd` | `class_name RunOverlay`. Minimal victory screen; pauses the game, shows score/coins, "Play again". Built at runtime by `game.gd`. |

## REPLACE files (full-file — diff before committing)

These are whole-file replacements of core systems. The intended delta in each is
listed so you can confirm the diff is *only* this and nothing in the untouched
logic drifted:

| File | Intended change (everything else unchanged) |
|---|---|
| `autoload/event_bus.gd` | Added two signals: `room_cleared(map_id)`, `run_completed()`. |
| `autoload/world_state.gd` | Added `_rooms_cleared` dict + `mark_room_cleared` / `is_room_cleared`, and `reset_run()` (wipes `_maps`, `_rooms_cleared`, `coins`). |
| `autoload/score_manager.gd` | `_on_map_changed` **no longer zeroes** score/power/meter — they now carry across rooms; it only re-syncs the HUD. Added `reset_run()`. `_on_player_damaged` still resets power on a hit (decision 6A); **score is untouched by damage**, so it survives death within a run. |
| `autoload/map_manager.gd` | `MAPS` now lists `room_01`…`room_10` (legacy `overworld_*` / `interior_*` kept, but unused by the run). Transition/respawn logic unchanged. |
| `autoload/dev.gd` | **F6 now deals lethal damage** instead of `queue_free` (so kills travel the normal death path and count toward room-clear — a raw free would softlock a gated room). Added **F10 = force-clear current room** (softlock failsafe). F1 overlay now also shows "mobs alive". |
| `maps/map_base.gd` | Added `@export var is_final` (read **after** `_build()`, so a room can set it in script); creates a `RoomController` (`_room`) before `_build()` and calls `_room.finalize(...)` after; new helpers `add_gate`, `add_door`, `add_mob_spawner`, `add_wall_run`, and `force_clear_room()`. Existing `place` / `add_exit` / `add_building` / tileset builder preserved. |
| `maps/mob_spawner.gd` | Skips spawning (frees itself) if the current room is already cleared — so cleared rooms stay empty on backtrack. |
| `ui/hud.gd` | Added a "Room N / 10" label and a door-status line (red "LOCKED — defeat all enemies" / green "OPEN — choose an exit"), driven by `map_changed` (lock state read from `WorldState`) and `room_cleared`. |
| `game.gd` | Starts the run at `room_01`; builds the `RunOverlay`; on `run_completed` shows victory, on restart calls `WorldState.reset_run()` + `ScoreManager.reset_run()` then reloads room_01. `game.tscn` is **unchanged** (overlay is built in code). |

---

## The room graph (undirected; identical every run)

```
        01
       /  \
     02    03
    / \   / \
  04   \ /   06
   |    X    |
   |   / \   |
   |  05   \ |
   |  | \   \|
   |  |  \   08
   \  |   \ / |
    \ |    X  |
     \|   / \ |
      07     09 ── 10  (final, leaf)
       \     /
        \   /
         (07,08 → 09)
```

Edges: 01–02, 01–03, 02–04, 02–05, 03–05, 03–06, 04–07, 05–07, 05–08, 06–08,
07–09, 08–09, 09–10. Doors/room: 01→2, 05 is the 4-door hub, 10 is the 1-door
finale. "Better/worse paths" are expressed by **difficulty**, not length —
e.g. the 06 branch is two brutes, the 04 branch is loose goblins. Path lengths
to the end are all ~6 rooms, so the choice is risk, not distance.

Difficulty ramp: 01 (2 goblins) → 04 (4 goblins) / 06 (2 brutes) →
05 & 08 (mixed, brute+orc) → 09 (2 orcs) → 10 (orc+brute+2 goblins).

---

## Debug keys (debug builds only)

F1 overlay (now incl. mobs-alive) · F2/F3/F4 spawn goblin/brute/orc at mouse ·
F5 barrel · **F6 kill all mobs (lethal, counts toward clear)** · F7 refill HP ·
F8 collision shapes · F9 stress test · **F10 force-clear current room**.

---

## Design calls I made (worth a playtest pass)

1. **Arena lock-in.** Entering an uncleared room locks **all** its doors,
   including the one you came in through — classic dungeon-room feel. The room
   you *came from* stays open (cleared rooms persist), so a door between a
   cleared and an uncleared room is open on the cleared side, locked on the
   uncleared side. If you'd rather leave the entry door open, it's a small change
   in `RoomController.finalize` (skip locking the gate whose `target`/spawn
   matches the arrival) — say the word.
2. **Score survives death; power doesn't.** Within a run, score and the power
   meter carry across rooms. Taking a hit still drops your multiplier (6A), and
   death (respawn-in-room) keeps your score. New run wipes everything.
3. **Clear detection is by count, not polling.** Each room declares its mob
   total synchronously; the controller tallies deaths. Reliable, but it assumes
   every defeated mob fires `entity_died` — which is why F6 was changed to deal
   damage rather than free.
4. **Softlock risk.** Since doors lock you in, a mob wedged somewhere unreachable
   would trap you. Rooms are open with central spawns to avoid it, but **F10**
   (and F6) are your escape hatch if it happens — flag any room where it does and
   I'll move the spawn.
5. **Attack-speed (SPEED) is still invisible.** The club's cooldown is 0, so the
   power-meter SPEED bonus has nothing to act on yet — unchanged from before,
   just noting it carries into the run now.
6. Legacy maps (`overworld_a/b`, `interior_house_a`) are still registered but
   not part of the run; their `RoomController` stays inert (no gates).
