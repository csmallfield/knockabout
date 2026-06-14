# KNOCKABOUT — Prototype

Top-down physics-driven Zelda-like ARPG prototype, built to the GDD. Everything
visible is placeholder art (colored circles/rects, runtime-generated tiles);
all the interesting work is in the impact pipeline and the data-driven
content framework.

## Content framework (resource-driven)

Every entity type is a single `.tres` profile under `resources/profiles/`.
An `EntityRegistry` autoload scans that folder at boot; each file becomes a
spawnable id (= filename). Maps, spawners, and debug keys reference ids, never
scenes — **adding a mob or block type is adding one file, zero code**:

| Profile | Defines | Spawn scene |
|---|---|---|
| `PlayerProfile` | physics stats, movement/roll/i-frames, body, weapon ref | player.tscn (direct ref) |
| `WeaponProfile` | damage/impulse/inherit, knockback mode, arc/blade/frames/cooldown, swing pattern, visual | (held by player) |
| `MobProfile` | physics stats, brain (walk/aggro), contact attack, body | generic `mob.tscn` |
| `PropProfile` | physics stats (+ break payload), LOOSE/ANCHORED body type, shape, color | generic `loose_prop.tscn` / `anchored_prop.tscn` |
| `DebrisProfile` | shard mass/hp/radius/color (referenced by payloads) | pooled shards |

PhysicsStats are embedded sub-resources inside each profile (explicit, no
cross-file ripples). To try a new attack feel: duplicate
`profiles/weapons/club.tres`, tweak, point `player.tres` at it. To add a
fourth mob: drop `profiles/mobs/troll.tres` and `place("troll", …)` it.
Duplicate ids across folders are rejected at boot with an error.

## Running it

1. Install **Godot 4.6.x** (standard build, no .NET needed).
2. Open the Project Manager → **Import** → select this folder's `project.godot`.
3. Press **F5** (Run Project). Main scene is `game.tscn`.

No external assets, no plugins, no import step beyond Godot's first scan.

## Controls

| Action | Keyboard | Mouse / Pad |
|---|---|---|
| Move | WASD / Arrows | Left stick |
| Attack (club swing) | J | LMB / X |
| Roll | K / Space | A |
| Interact (doors) | E | Y |

## Debug keys (debug builds only — compiled out via `OS.is_debug_build()`)

| Key | Effect |
|---|---|
| F1 | Stats overlay (FPS, bodies, ballistic actors, debris, impacts/tick) |
| F2 / F3 / F4 | Spawn goblin / brute / orc at mouse |
| F5 | Spawn barrel at mouse |
| F6 | Clear all mobs |
| F7 | Refill player HP |
| F8 | Toggle collision shape drawing |
| F9 | Stress test: 20 mobs + barrel field at mouse |

## What's implemented (vs. GDD)

- Full hybrid physics model: CharacterBody2D actors with GROUNDED → BALLISTIC →
  STUNNED state machine, RigidBody2D loose props, StaticBody2D anchored props.
- Single `ImpactResolver` autoload — every point of damage in the game flows
  through the one momentum-exchange formula (kinetic, kinematic-collision,
  and synthetic weapon-swing entry points). Pair cooldowns, per-tick throttle,
  overkill break-in-place.
- Player: walk, roll (i-frames + shove), club swing as a visible 32 px club swept across the arc, its blade Area2D the contact volume, driven
  entirely by `WeaponStats` resource data (D5 hook for charge levels present).
- Mobs: goblin / brute / orc with engagement HP bars, shared `MobBase` brain (idle → aggro → contact
  attack), stats per the GDD table.
- Breakables with debris bursts from a 120-shard pool, tree → stump variant,
  per-session destruction persistence via `WorldState`.
- Three connected maps (overworld A ↔ B, interior with roof-fade building),
  map transitions with fades, death → respawn at default spawn.
- Juice: hit-stop, trauma² camera shake, flash-white, squash, four generated
  SFX blips (no audio files).

Not in scope (per GDD phasing): inventory/equipment beyond the single club
resource, save-to-disk persistence, charge attacks (data hook only).

## Deviations from the GDD — read this

1. **Minimal `.tscn` files.** Scenes are root-node-plus-script with exported
   resource references; node internals (colliders, art, hitboxes) are built in
   `_ready()`. This makes the hand-off reliable (no hand-authored sub-node
   trees to corrupt), at the cost of editor-tweakability. If you want to art
   these up later, the build code in each `_ready()` is the spec to replace.
2. **Runtime TileSet.** The tileset (2 ground tiles + 1 wall tile with physics
   polygon) is generated in code in `MapBase`; map layouts are authored in the
   map scripts (`fill_ground`, `border_walls`, `wall_cell`, …), not painted
   tilemaps. Swap in a painted TileMapLayer per map when art exists.
3. **Prop contact normals** are approximated from body-position deltas rather
   than true contact manifolds (Godot's RigidBody contact reporting is noisy
   at these speeds; position-delta is stable and visually indistinguishable
   for circles/AABBs).
4. **`velocity_inherit`** is implemented as
   `impulse += inherit × max(0, v·dir) × player_mass` — i.e. only the velocity
   component *toward the target* counts, scaled to an impulse. Straight
   velocity addition felt wrong when strafing past targets.

## Tuning notes

- The roll grants i-frames against **damage only**, not knockback (GDD §6.3) —
  rolling through an orc still shoves you. If that reads as unfair in play,
  the gate is in `Player.take_impact_damage` / `apply_impact_result`.
- Orc vs. player soft-knockback: with player launch_speed 280 and orc contact
  impulse 35000/m100 = 350 px/s, orc hits launch you. Brute (140 px/s) gives
  soft knockback instead. That contrast is intentional; tune via
  `contact_impulse` in the mob scenes.
- All simulation-rule constants (energy→damage, throttles, stun times) live in
  `autoload/tuning.gd`; ALL content lives in `resources/profiles/`. Nothing
  gameplay-relevant is hardcoded elsewhere. Deliberate split: profiles are
  content you tune per-thing; Tuning is physics law you change knowingly.

## Layout

```
autoload/    tuning, event_bus, world_state, entity_registry (id → profile,
             spawning), impact_resolver, debris_pool, map_manager, dev
components/  ballistic_motion, health_component, breakable
systems/     impact_event (the one damage currency)
entities/    player/, mobs/mob.tscn, props/{loose,anchored}_prop.tscn —
             generic scenes that build themselves from a profile
maps/        map_base + 3 maps, exit_area, building_roof, mob_spawner
resources/   profile Resource scripts + profiles/ (player, weapons/, mobs/,
             props/, debris/ — the entire content of the game)
fx/          feedback_manager (hit-stop, shake, generated SFX)
ui/          hud
```
