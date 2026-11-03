# Handoff: Knockabout crowd performance

A brief for a local session on Chris's machine (Windows, RTX 3080). The goal is more
enemies, bigger dungeons and more physics props (knock an enemy into an explosive barrel,
chain reactions) without losing the feel. Everything below was measured in a 2-core cloud
container with no real GPU. Treat its numbers as relative, and measure again here first.

## The three gameplay goals (never trade these away)

1. The knock-around physics are the core of the game.
2. Large numbers of enemies.
3. Enemies colliding with each other, with props and with the environment.

A change that wins frame time by weakening any of these is a regression.

## Where things stand

Branch `feat/puppets` (PR #1) on top of `main`:

- The player and every mob are 2D cutout puppets. The motion kit's `MotionCutoutAtlas` and
  `MotionCutoutRig2D` (kit branch `feat/cutout-2d`, pinned as the `vendor/godot-motion-kit`
  submodule) draw them. See README "Puppets".
- `components/mob_grid.gd`: one spatial hash per physics tick for brain separation. It
  replaced an n² scan of the whole "mobs" group.
- `components/mob_brain.gd` reuses one `PhysicsRayQueryParameters2D` instead of allocating
  one per ray.
- `tools/bench.gd` runs the crowd bench; `tools/pose_sheet.gd` makes the hero pose strip.

Setup: `.\tools\setup.ps1` links the kit into `addons/motion_kit`. Godot 4.6.x.

## How to measure

```
godot --headless --path . --fixed-fps 60 -- --bench --mobs=120 --bench-time=15
godot --headless --path . --fixed-fps 60 -- --bench --mobs=120 --no-pose   # puppets frozen
```

The bench spawns N mobs round the player (topped up as they die), keeps the player alive and
swinging, and prints:

- `wall`: CPU ms per frame, all script and engine work. Headless, so no frame rate.
- `puppets`: posing cost per frame and per pose.

Also run windowed with F1 on (the frame time readout) and use Godot's profiler and
visual profiler for the real split, including the GPU. The cloud only ever saw the
Compatibility renderer, so compare Forward+ and Compatibility here.

**First task: extend the bench before changing anything.** Add per-system timings
(brain, `BallisticMotion` / `move_and_slide`, `ImpactResolver`, puppets), for example with
the motion kit's `MotionPerfProbe`. A temporary version of this was written in the cloud
and removed. Record a baseline table at 60 / 120 / 200 / 400 mobs.

## Cloud measurements (2-core shared Xeon, headless)

Wall ms per frame:

| Mobs | `main` (circles) | `feat/puppets` |
| --- | --- | --- |
| 20 | 3.3 | 3.9 |
| 60 | 10.2 | 8.7 |
| 120 | 24.4 | 17.7 |
| 200 | 41.9 | 30.8 |

Split at 120 mobs after the grid fix:

| System | ms / frame | Language |
| --- | --- | --- |
| Brain (all) | ~8.4 → ~5 | GDScript |
| ↳ perception (LOS + 16 danger rays every 0.12 s) | ~2.5 | GDScript + physics queries |
| ↳ separation | ~3 → small after MobGrid | GDScript |
| ↳ `_choose_dir` (Dictionary goals × 16 slots) | ~1.4 | GDScript |
| `BallisticMotion` (`move_and_slide` / `move_and_collide`) | ~4 | engine C++ |
| Puppet posing (~33 µs per pose, LOD-limited) | ~1.9 | GDScript |

Before this session the n² separation scan was the biggest single cost. The puppets were never
the bottleneck.

## The plan, in order

Measure after every step. Keep a step only if it measurably helps and the game feels the same.

### Step 1: Cheap GDScript wins (no architecture change)

Expected: roughly 200+ mobs in the cloud's budget, more on a desktop CPU.

1. **AI level of detail.** Run `MobBrain.think()` at 20–30 Hz, staggered by mob, as the
   puppets already do. Keep the last intent between thinks. Keep it every tick while the mob
   is winding up, striking, or is near the player and holds an attack token. Movement
   (`BallisticMotion`) stays at 60 Hz.
2. **Perception.**
   - Spread the danger whiskers over frames: 4 of the 16 per tick instead of 16 every
     0.12 s, so it's a steady load instead of spikes.
   - Raise `AI_PERCEPTION_INTERVAL` for mobs far from the player.
   - Consider 8 rays, interpolated into the 16 slots.
   - Share one LOS check per mob per perception tick.
3. **`_choose_dir`.** Replace the Array of Dictionary goals with packed arrays, or a
   fixed small struct of (dir, weight) pairs, and avoid allocating per call.
4. **`get_player()`.** Cache the player once per tick, globally. `Puppets.player_pos`
   already does this for the puppets.
5. **Sleep inactive rooms and off-screen far mobs.** Bigger dungeons should cost nothing
   for rooms the player isn't in. Off screen and far away: no brain, no posing, and
   optionally a cheap movement step.
6. **Puppets**, if they show up in the profile:
   - Pose idle mobs on threes earlier (`CROWD_2` / `CROWD_3` in `mob_puppet.gd`).
   - Skip `_knock` work for grounded idle mobs.
   - Check whether `apply()` can skip parts whose transform didn't change.

### Step 2: Decide on a native crowd core (only if Step 1 isn't enough)

**What C++ fixes and what it doesn't.** Porting GDScript loops (brain, steering, puppet
forward kinematics) to C++ is typically 10–30× faster for that maths. The
`move_and_slide` cost is already engine C++: it comes from one CharacterBody2D per mob
going through the physics server, and porting the calls changes nothing. A C++ brain
plus C++ puppets alone would roughly halve the frame, landing at maybe 250–300 mobs. The
physics wall would remain.

**The bigger win is data-oriented crowd simulation.** One system owns every mob's position,
velocity, state and brain data in flat arrays. Each tick it does:

- AI and steering for the active mobs;
- integration;
- mob–mob and mob–prop collision as circles, through the spatial grid (MobGrid's idea,
  in native code);
- wall collision against the tilemap (cell queries) or a static collision shape set;
- impacts through the same momentum exchange as `ImpactResolver._exchange`, unchanged
  formula, so the feel carries over;
- writing puppet transforms straight to the RenderingServer (no nodes per part).

That is exactly the workload of the knockabout gameplay: launched bodies hitting bodies,
chain reactions, an explosive barrel throwing twenty goblins. A native core of this kind
handles hundreds to low thousands of bodies.

What Godot keeps: the player (or the player joins the core as a special body), rooms,
gates, UI, loot, scoring, and the `EventBus` signals (the core emits `entity_died`,
impacts, etc.).

**Options to compare before committing:**

| Option | For | Against |
| --- | --- | --- |
| A. GDExtension (godot-cpp) crowd core | Fastest; full control of the feel; the audio kit's native core already proves the build and CI path | Recompile to iterate; debugging across the boundary; you own physics edge cases |
| B. C# for the brain and crowd | Much faster than GDScript, no native build | Still node-bound unless also data-oriented; a .NET build of Godot; slower than A |
| C. A 2D physics extension (e.g. a Rapier 2D GDExtension) in place of Godot physics | Possibly much faster bodies with no custom solver | Check its current state first; the game's impact model sits on top of physics callbacks and may not map 1:1 |
| D. GDScript data-oriented crowd (arrays, no per-mob nodes) | No build step; tests the architecture cheaply | GDScript maths cost stays; a prototype step toward A |

A sensible route: prototype **D** first, to prove the data layout and the feel, then port
its hot loops to **A**.

**Risks a custom solver brings back** (Godot physics handles these today):

- Tunnelling at high launch speeds: sub-step or sweep fast bodies.
- Stacking and jitter in packed crowds.
- Mobs pinned against walls by the crowd.
- Corner cases in gates and doors.

Write a small physics test scene for each before switching.

### Step 3: Rendering at scale (only past ~500 puppets)

At about 16 sprites per puppet, 500 puppets is about 8,000 canvas items. The next step there:

- one `MultiMeshInstance2D` for the whole crowd, sorted by y in the core;
- props that must interleave drawn into the same sort, or into a second multimesh;
- the same atlas and material as now (`MotionCutoutAtlas`).

Check the visual profiler on Forward+ before doing any of this. Batching may hold up well
past that point on the 3080.

## Related open items from the puppet work

- **Hero readability in dense crowds.** The gold ring isn't enough when big orcs stand in
  front. Options:
  - draw the hero above mobs (z_index): simple, but it breaks y-sort depth with them;
  - an outline or silhouette of the hero drawn through anything covering it: a second
    pass of the hero's rig in a flat colour at low alpha, on top.
- **Tuning by eye on a real display:**
  - flash strength;
  - hop height and tumble spin on launch;
  - walk cycles on twos and threes in big crowds;
  - the paper turn on the hero.

## Ground rules

- Reusable techniques go into the kits (motion kit: rig, atlas, LOD helpers), with tests,
  API.md entries and skill notes. Game-specific code stays in Knockabout.
- Keep the momentum-exchange formula and tuning data (`.tres` profiles) as the single
  source of the feel, whatever runs the simulation.
- Commit and push at each step with the bench table updated in the README.
