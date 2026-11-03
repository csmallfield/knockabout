# KNOCKABOUT — Prototype

Top-down physics-driven Zelda-like ARPG prototype, built to the GDD. The player and
mobs are 2D cutout puppets (see Puppets below); the rest is placeholder art (colored
circles/rects, runtime-generated tiles);
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

1. Install **Godot 4.6 or newer** (standard build, no .NET needed).
2. Run the setup script **before opening the project in Godot for the first time** on
   each machine:

   ```
   tools/setup.sh          # Linux / macOS
   .\tools\setup.ps1       # Windows (PowerShell)
   ```

   The puppets use the Godot Motion Kit's 2D cutout rig. The script fetches the
   `vendor/godot-motion-kit` submodule and links its addon into `addons/motion_kit`
   (a symlink, or a directory junction on Windows, so no admin rights are needed).
   `addons/motion_kit` is gitignored, which is why this is a per-clone step rather than
   something git brings across. The kit is private for now, so this needs access to it.
   To work against your own kit checkout instead of the submodule:
   `KITS_DIR=~/dev tools/setup.sh` or `.\tools\setup.ps1 -KitsDir C:\dev`.
3. Open the Project Manager → **Import** → select this folder's `project.godot`.
4. Press **F5** (Run Project). Main scene is `game.tscn`.

### If you opened the project before running setup

Without the addon, Godot fails to compile every puppet script (`Could not resolve class
"Puppet"`, `Identifier "MotionCutoutRig2D" not declared`, and so on), reports that
`res://addons/motion_kit/plugin.cfg` failed to load, and silently rewrites the
`art/*.svg.import` files to use the plain texture importer instead of the kit's SVG
importer. Running setup afterwards is not enough on its own: the SVGs must also be
restored to the kit importer, otherwise the puppet atlas can't bake. Do both:

```
.\tools\setup.ps1                 # or tools/setup.sh
git checkout -- art/*.svg.import
```

Then reopen the project. Godot re-imports the SVGs with the motion kit importer on the
first open.

## Puppets

The player and every mob are 2D cutout puppets: the Cutout Isle hero drawings
(`art/hero_front|back|side.svg`) baked by the motion kit's `MotionCutoutAtlas` into one
texture at boot (`autoload/puppets.gd`), each drawn by a `MotionCutoutRig2D`.

- **Hero** (`entities/puppet/hero_puppet.gd`): four directions with the sword always in the
  right hand (front and back never flip; facing left is the side drawing mirrored with
  left and right swapped), a paper turn between views, walk cycle, and the sword hand on
  IK riding the club pivot's actual swing arc, the same arc as the hitbox. The sword arm
  draws in front of the body when the arc comes toward the camera. Charge leans in,
  block raises the free arm, roll spins the body. A gold ground ring keeps the hero
  readable in a crowd of copies; only the hero wears the scarf.
- **Mobs** (`entities/puppet/mob_puppet.gd`): the hero recoloured per `MobProfile` at
  bake time (skin from `color`, darker hair, muted complementary clothes; override with
  the profile's Puppet group), sized by `radius × puppet_height`. A lite driver: walk,
  wind-up and strike poses from the brain.
- **Knock layer** (`entities/puppet/puppet.gd`, both): read straight off `BallisticMotion`.
  Launched bodies hop and tumble with their speed, limbs trail the velocity and flail,
  impacts squash, stunned bodies lie tilted and wobble, corpses topple and fade.
- **Purely visual.** The circle collider is still the body; physics is unchanged.
- **LOD.** Off screen: no posing. Launched, stunned, hit, dying, winding up or striking:
  every frame. Otherwise every frame up to 24 puppets, every 2nd up to 60, every 3rd
  beyond (at most every 2nd within 140 px of the player), staggered, with the skipped
  time carried into the next pose.

Everything shares one texture and one material, so the crowd batches: 40 mobs and the
room drew in about 100 draw calls under the Compatibility renderer.

`godot --path . -- --pose-sheet` drives the hero through every facing, swing, block,
roll and charge and saves a strip of crops to `user://pose_sheet.png`.

## Crowd bench

`godot --headless --path . --fixed-fps 60 -- --bench --mobs=120 [--bench-time=15]`
spawns N mobs round the player (topped up as they die), keeps the player alive and
swinging, and prints CPU time per frame and puppet posing cost. `--no-pose` freezes the
puppets to isolate their cost. Headless numbers are CPU cost only, never frame rate.

On the 2-core cloud CPU these were measured on (wall ms per frame, all CPU work):

| Mobs | Before (circles) | Now (puppets + MobGrid) | Puppet posing |
| --- | --- | --- | --- |
| 20 | 3.3 | 3.9 | 0.6 |
| 60 | 10.2 | 8.7 | 1.1 |
| 120 | 24.4 | 17.7 | 1.9 |
| 200 | 41.9 | 30.8 | 2.8 |

The puppets cost about 33 µs per pose. They come out net faster from 60 mobs up
because the brain's separation used to scan every mob for every mob (n² per tick);
`components/mob_grid.gd` now shares one spatial hash per tick, and the brain reuses one
ray query instead of allocating one per ray. What's left at 120 mobs is mostly the brain
(perception raycasts and context steering, about 5 ms here) and `move_and_slide`
(about 4 ms). Measure on your machine before tuning further. The plan for going further (AI level of
detail, a data-oriented crowd core, native code) is in
[docs/HANDOFF_performance.md](docs/HANDOFF_performance.md).

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
