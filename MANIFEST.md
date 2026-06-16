# Knockabout — Scoring, Power Meter & Loot — drop-in manifest

Unzip at the project root; the tree mirrors `res://`. **REPLACE** files overwrite
existing ones; **NEW** files are additions. Two edits to `project.godot` are
manual merges (bottom of this file).

## New scripts
| File | res:// path |
|---|---|
| scoring_config.gd | `resources/scoring_config.gd` |
| loot_profile.gd   | `resources/loot_profile.gd` |
| loot_drop.gd      | `resources/loot_drop.gd` |
| loot_table.gd     | `resources/loot_table.gd` |
| buff_component.gd | `components/buff_component.gd` |
| pickup.gd         | `entities/pickup.gd` |
| pickup_pool.gd    | `autoload/pickup_pool.gd` |
| score_manager.gd  | `autoload/score_manager.gd` |

## Replacement scripts (overwrite)
| File | res:// path | What changed |
|---|---|---|
| event_bus.gd        | `autoload/event_bus.gd`        | + `player_damaged` signal |
| tuning.gd           | `autoload/tuning.gd`           | + `L_LOOT`, `PICKUP_POOL_SIZE` |
| impact_resolver.gd  | `autoload/impact_resolver.gd`  | `resolve_synthetic()` + optional `swing_hits` arg |
| world_state.gd      | `autoload/world_state.gd`      | + persistent `coins` |
| impact_event.gd     | `systems/impact_event.gd`      | + `swing_hits` field |
| health_component.gd | `components/health_component.gd` | + `heal(amount)` |
| mob_profile.gd      | `resources/mob_profile.gd`     | + `point_value`, `loot` |
| player_profile.gd   | `resources/player_profile.gd`  | + `speed_attack_scaling` |
| player.gd           | `entities/player/player.gd`    | buffs, collect/heal, swing-hit stamp, invincibility |
| hud.gd              | `ui/hud.gd`                    | score / coins / power bar |

## New resources
| File | res:// path |
|---|---|
| scoring_config.tres | `resources/scoring_config.tres` (NOT under profiles/ — see note) |
| coin.tres / health.tres / power.tres / speed.tres / invincible.tres | `resources/profiles/loot/` |
| basic_loot.tres | `resources/profiles/loot/basic_loot.tres` |

## Replacement resources (overwrite)
| File | res:// path | What changed |
|---|---|---|
| goblin.tres | `resources/profiles/mobs/goblin.tres` | + `point_value = 8`, `loot` |
| brute.tres  | `resources/profiles/mobs/brute.tres`  | + `point_value = 20`, `loot` |
| orc.tres    | `resources/profiles/mobs/orc.tres`    | + `point_value = 40`, `loot` |

---

## project.godot — two manual merges

### 1. [autoload] — add these two lines after CombatDirector:
```
PickupPool="*res://autoload/pickup_pool.gd"
ScoreManager="*res://autoload/score_manager.gd"
```

### 2. [layer_names] — add the 8th physics layer:
```
2d_physics/layer_8="LOOT"
```

---

## Notes / gotchas

- **`scoring_config.tres` placement.** It lives in `resources/`, not
  `resources/profiles/`, on purpose: `EntityRegistry` scans `profiles/` and turns
  every `.tres` into a spawnable id. Keeping the config out of that folder avoids
  a junk "scoring_config" id. The loot profiles DO live under `profiles/loot/`,
  which is fine — they're loaded but never spawned, exactly like `debris/`.

- **`basic_loot.tres` is the one hand-authored typed-array file.** Its `drops`
  line uses `Array[LootDrop]([...])`. If your Godot build rejects that notation on
  import, the zero-risk fix is to open `basic_loot.tres` in the inspector and drag
  the four loot profiles into the `drops` array there (the editor rewrites the
  notation correctly). Everything else is flat `.tres` with no array risk.

- **SPEED's attack-speed half is currently invisible** because `club.tres` has
  `cooldown = 0.0`; the movement speed-up still shows. It activates the moment a
  weapon has a real cooldown.

- **Loot velocity** scatters randomly off the kill. The GDD wanted it to inherit
  the death's incoming velocity, but `EventBus.entity_died` doesn't carry that.
  Say the word and I'll widen `entity_died` to pass it through (touches Breakable
  + FeedbackManager's handler).

- **Indirect-hit trickle.** Debris-into-debris technically qualifies as an
  "indirect" hit while a combo is live, so a big debris burst mid-combo can add a
  little meter. The `indirect_needs_combo` gate limits it. If it bugs you in
  playtest, add a "≥1 party is a mob" check to `ScoreManager._is_indirect`.
