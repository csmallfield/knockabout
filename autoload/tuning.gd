extends Node
## Global tuning constants (GDD §5.5). One place to turn knobs.

const ENERGY_TO_DAMAGE := 2.0e-6     # goblin (m30) wall-slam @800 px/s ≈ 19 dmg
const MIN_IMPACT_SPEED := 120.0      # px/s — below this: bounce, no damage
const OVERKILL_FACTOR := 2.0         # single hit ≥ 2× max_hp ⇒ break in place
const PAIR_COOLDOWN := 0.12          # s — duplicate-impact guard
const REST_SPEED := 60.0             # px/s — ballistic → stunned
const SOFT_KNOCKBACK_DECAY := 8.0    # /s — grounded knockback falloff
const TANGENT_FRICTION := 0.95       # tangential velocity retained per bounce
const DEBRIS_LIFETIME := 6.0         # s — then fade + return to pool
const MAX_IMPACTS_PER_TICK := 64     # resolver throttle (GDD §8.2)
const DEBRIS_POOL_SIZE := 120        # pre-instantiated shards (D7)

const STUN_TIME_DEFAULT := 0.35      # s — mob landing stun
const STUN_TIME_PLAYER := 0.2        # s — player landing stun (shortened, §4.1)
const STATIC_RESTITUTION := 0.5      # assumed restitution of statless surfaces (tiles)

# --- Collision layer bit values (GDD §10) ---
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_PROP := 8
const L_HITBOX := 16
const L_HURTBOX := 32
const L_INTERACT := 64

const TILE := 32
