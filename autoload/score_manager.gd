extends Node
## Scoring + power meter + loot resolution (GDD §3–§6). A pure listener on the
## bus: it *reads* combat and never deals damage or moves bodies. Modelled on
## CombatDirector. Score/power/coin signals live here (system state); the HUD
## reads only these + EventBus.
##
## Decay runs in REAL time: FeedbackManager._hitstop sets Engine.time_scale to
## 0.05, so a naive _process(delta) decay would stall. We compute our own
## real-time delta from Time.get_ticks_msec(), the same trick _hitstop uses.

signal score_changed(score: float)
signal power_changed(level: int, meter_ratio: float)
signal coins_changed(total: int)

const CONFIG_PATH := "res://resources/scoring_config.tres"
const COIN_PROFILE_PATH := "res://resources/profiles/loot/coin.tres"

var score := 0.0
var power_level := 0    # 0 ⇒ ×1
var meter := 0.0

var _config: ScoringConfig
var _coin_profile: LootProfile
var _combo_timer := 0.0
var _last_msec := 0

func _ready() -> void:
	_config = load(CONFIG_PATH) as ScoringConfig
	if _config == null:
		_config = ScoringConfig.new()
		push_warning("ScoreManager: %s missing — using ScoringConfig defaults." % CONFIG_PATH)
	_coin_profile = load(COIN_PROFILE_PATH) as LootProfile
	if _coin_profile == null:
		push_warning("ScoreManager: %s missing — coins won't drop." % COIN_PROFILE_PATH)

	EventBus.impact_occurred.connect(_on_impact)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	# map_changed fires (deferred) after the HUD has connected, so this is also
	# our chance to push initial values onto a freshly-built HUD.
	EventBus.map_changed.connect(_on_map_changed)

	_last_msec = Time.get_ticks_msec()

# ----------------------------------------------------------------- public API

## The one mutator the player calls (POWER pickup). Bar carries (decision 7A):
## meter is untouched, so the carried fill becomes a smaller fraction of the now
## costlier next level — which reads correctly.
func add_power_levels(n: int) -> void:
	if n <= 0:
		return
	power_level += n
	_emit_power()

## COIN collect. The total lives in WorldState (persistent); we keep HUD synced.
func add_coins(n: int) -> void:
	if n <= 0:
		return
	WorldState.add_coins(n)
	coins_changed.emit(WorldState.get_coins())

func multiplier() -> float:
	return 1.0 + float(power_level)   # applied to POINTS only (decision 5A)

func fill_cost(level: int) -> float:
	return _config.base_fill_cost * pow(_config.fill_cost_growth, level)

# ----------------------------------------------------------------- real-time decay

func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_dt := float(now - _last_msec) / 1000.0
	_last_msec = now
	if real_dt <= 0.0:
		return
	real_dt = minf(real_dt, 0.1)   # guard against first frame / long pauses

	if _combo_timer > 0.0:
		_combo_timer -= real_dt
		return
	if meter <= 0.0 and power_level == 0:
		return   # nothing to bleed

	meter -= _config.meter_decay_rate * real_dt
	# Underflow drops a level and lands near the top of the lower bar:
	# new meter = fill_cost(new_level) − overflow  (§3, §5).
	while meter < 0.0 and power_level > 0:
		power_level -= 1
		meter += fill_cost(power_level)
	if power_level == 0:
		meter = maxf(meter, 0.0)
	_emit_power()

# ----------------------------------------------------------------- combat listeners

func _on_impact(event: ImpactEvent, damage: float) -> void:
	# Meter only builds when a live MOB takes the hit (body_b). Props, debris,
	# and walls never feed it — even on a direct player swing. (This also retires
	# the old debris-into-debris trickle worry.)
	if not _is_mob(event.body_b):
		return
	var gain := 0.0
	if _is_player(event.body_a):
		# Direct: a hit the player instigated on a mob — swing (synthetic), roll
		# shove, or a player-ballistic bonk (§4 + the §10 roll-credit rec).
		gain = _config.per_hit_meter + _config.damage_meter_factor * damage
		if event.swing_hits >= 2:
			gain *= _config.multi_hit_mult       # multi-hit only applies to swings
	elif _is_indirect(event, damage):
		gain = (_config.per_hit_meter + _config.damage_meter_factor * damage) * _config.bounce_mult
	else:
		return

	meter += gain
	_combo_timer = _config.combo_grace

	# Multiple level-ups in one big hit are fine.
	while meter >= fill_cost(power_level):
		meter -= fill_cost(power_level)
		power_level += 1
	_emit_power()

func _on_entity_died(entity: Node, _stats: PhysicsStats, _map_id: String) -> void:
	if entity == null:
		return
	var profile = entity.get("profile")
	if not (profile is MobProfile):
		return   # props leave point_value/loot absent → silent (§6.1)
	var mob := profile as MobProfile

	if mob.point_value > 0.0:
		score += mob.point_value * multiplier()
		score_changed.emit(score)

	_resolve_loot((entity as Node2D).global_position, mob.loot)

func _on_player_damaged(_amount: float) -> void:
	# Full reset to ×1, empty bar (decision 6A).
	power_level = 0
	meter = 0.0
	_combo_timer = 0.0
	_emit_power()

func _on_map_changed(_map_id: String) -> void:
	# Run-local state resets; coins persist in WorldState. Also (re)seeds a
	# freshly-built HUD with current values.
	score = 0.0
	power_level = 0
	meter = 0.0
	_combo_timer = 0.0
	score_changed.emit(score)
	_emit_power()
	coins_changed.emit(WorldState.get_coins())

# ----------------------------------------------------------------- loot (§6.3)

func _resolve_loot(pos: Vector2, table: LootTable) -> void:
	if table == null:
		return
	# Coins roll independently of the weighted special slot.
	if _coin_profile:
		for i in randi_range(table.coin_min, table.coin_max):
			PickupPool.spawn(pos, _eject_velocity(), _coin_profile)
	# One weighted special, gated by drop_chance.
	if not table.drops.is_empty() and randf() < table.drop_chance:
		var drop := _pick_weighted(table.drops)
		if drop and drop.loot:
			PickupPool.spawn(pos, _eject_velocity(), drop.loot)

func _eject_velocity() -> Vector2:
	# Small random scatter off the kill (see note: entity_died doesn't carry the
	# death's incoming velocity, so we don't inherit it here).
	return Vector2.RIGHT.rotated(randf() * TAU) * randf_range(60.0, 140.0)

func _pick_weighted(drops: Array) -> LootDrop:
	var total := 0.0
	for d in drops:
		if d:
			total += maxf(d.weight, 0.0)
	if total <= 0.0:
		return null
	var roll := randf() * total
	for d in drops:
		if d == null:
			continue
		roll -= maxf(d.weight, 0.0)
		if roll <= 0.0:
			return d
	return drops.back()

# ----------------------------------------------------------------- helpers

func _emit_power() -> void:
	power_changed.emit(power_level, clampf(meter / fill_cost(power_level), 0.0, 1.0))

func _is_player(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.is_in_group("player")

## A live mob — i.e. in the "mobs" group. Dying corpses leave the group, so they
## can't farm meter, and props/debris/walls are never in it.
func _is_mob(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.is_in_group("mobs")

## Indirect: enemy-into-enemy or prop-into-enemy (the scoped-down "bounce"
## reward, §4). Both parties are entities, neither is the player, real damage
## landed, and — unless disabled — a combo is live so ambient physics doesn't
## trickle-fill the bar.
func _is_indirect(event: ImpactEvent, damage: float) -> bool:
	if event.synthetic or damage <= 0.0:
		return false
	if not (_is_entity(event.body_a) and _is_entity(event.body_b)):
		return false
	if _is_player(event.body_a) or _is_player(event.body_b):
		return false
	if _config.indirect_needs_combo and _combo_timer <= 0.0:
		return false
	return true

func _is_entity(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.has_method("get_stats")
