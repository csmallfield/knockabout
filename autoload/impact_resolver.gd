extends Node
## The one place the hybrid physics worlds meet (GDD §4, §5.3).
## Every damaging collision in the game resolves here against PhysicsStats.

var _pair_times := {}              # { "idA_idB": last_resolve_time }
var _tick := -1
var impacts_this_tick := 0         # exposed for the debug overlay

# ------------------------------------------------------------------ public

## Main entry point. Resolves damage + momentum exchange for an ImpactEvent.
func resolve(event: ImpactEvent) -> void:
	var t := Engine.get_physics_frames()
	if t != _tick:
		_tick = t
		impacts_this_tick = 0

	if not _pair_ok(event):
		return

	# Throttle (GDD §8.2): excess impacts get a damage-free bounce only.
	if impacts_this_tick >= Tuning.MAX_IMPACTS_PER_TICK:
		_write_back(event, _exchange(event), false, false)
		return
	impacts_this_tick += 1

	var n := event.normal
	var v_n := maxf(event.rel_velocity.dot(n), 0.0)  # closing speed along normal

	# Sub-threshold physical contact: bounce, no damage (§5.2).
	if not event.synthetic and v_n < Tuning.MIN_IMPACT_SPEED:
		_write_back(event, _exchange(event), false, false)
		return

	var sa := _stats(event.body_a)
	var sb := _stats(event.body_b)

	# Damage is kinetic energy (§5.2). m_eff = reduced mass; static ⇒ moving mass.
	var m_a: float = sa.mass if sa else INF
	var m_b: float = sb.mass if sb else INF
	var m_eff: float
	if is_inf(m_a): m_eff = (m_b if not is_inf(m_b) else 0.0)
	elif is_inf(m_b): m_eff = m_a
	else: m_eff = m_a * m_b / (m_a + m_b)
	var energy := 0.5 * m_eff * v_n * v_n
	var base_dmg := Tuning.ENERGY_TO_DAMAGE * energy

	# Both parties take base impact damage; receiver additionally takes
	# flat weapon damage. Asymmetry comes from toughness/max_hp only (§5.2).
	var dmg_a := 0.0 if event.synthetic else base_dmg
	var dmg_b := base_dmg + event.flat_damage

	if sa and dmg_a <= sa.toughness: dmg_a = 0.0
	if sb and dmg_b <= sb.toughness: dmg_b = 0.0

	# Overkill check (§5.3.5): break in place this frame, skip launch.
	var overkill_a := sa != null and sa.breakable and dmg_a >= Tuning.OVERKILL_FACTOR * sa.max_hp
	var overkill_b := sb != null and sb.breakable and dmg_b >= Tuning.OVERKILL_FACTOR * sb.max_hp

	# Momentum exchange (§5.4) + synthetic impulse, then write velocities back.
	var new_v := _exchange(event)
	if event.synthetic and sb and not is_inf(m_b):
		new_v[1] += n * (event.synthetic_impulse / m_b)
	_write_back(event, new_v, overkill_a, overkill_b)

	# Apply damage last so break payloads can read final velocities.
	if dmg_a > 0.0 and event.body_a and event.body_a.has_method("take_impact_damage"):
		event.body_a.take_impact_damage(dmg_a, event)
	if dmg_b > 0.0 and event.body_b and event.body_b.has_method("take_impact_damage"):
		event.body_b.take_impact_damage(dmg_b, event)

	EventBus.impact_occurred.emit(event, maxf(dmg_a, dmg_b))

## Convenience: a ballistic actor's move_and_collide result (§4.2 rows 1–3).
func resolve_kinematic(actor: Node, col: KinematicCollision2D, velocity: Vector2) -> void:
	var other := col.get_collider()
	var ev := ImpactEvent.new()
	ev.body_a = actor
	ev.body_b = other if _is_entity(other) else null
	ev.normal = -col.get_normal()          # from actor toward surface
	ev.contact_point = col.get_position()
	ev.rel_velocity = velocity - _vel(ev.body_b)
	resolve(ev)

## Convenience: synthetic weapon / contact-attack hit (§4.2 rows 5–6, §6.1).
## swing_hits: # distinct enemies the player's current swing has hit (incl. this
## one), stamped onto the event for the multi-hit meter bonus (§2.6). Everyone
## but the player leaves it at the default 0.
func resolve_synthetic(attacker: Node, target: Node, dir: Vector2,
		impulse: float, flat_damage: float, contact := Vector2.ZERO,
		swing_hits := 0, bypass_cooldown := false) -> void:
	var ev := ImpactEvent.new()
	ev.body_a = attacker
	ev.body_b = target
	ev.normal = dir.normalized()
	ev.contact_point = contact
	ev.rel_velocity = _vel(attacker) - _vel(target)
	ev.synthetic = true
	ev.synthetic_impulse = impulse
	ev.flat_damage = flat_damage
	ev.swing_hits = swing_hits
	ev.bypass_cooldown = bypass_cooldown
	resolve(ev)

## Convenience: two live bodies meeting (roll shove, prop contact reports).
func resolve_body_pair(a: Node, b: Node, contact := Vector2.ZERO) -> void:
	if not (_is_entity(a) and _is_entity(b)):
		return
	var ev := ImpactEvent.new()
	ev.body_a = a
	ev.body_b = b
	ev.normal = (b.global_position - a.global_position).normalized()
	if ev.normal == Vector2.ZERO:
		ev.normal = Vector2.RIGHT
	ev.contact_point = contact if contact != Vector2.ZERO else b.global_position
	ev.rel_velocity = _vel(a) - _vel(b)
	resolve(ev)

# ----------------------------------------------------------------- private

func _exchange(event: ImpactEvent) -> Array[Vector2]:
	# 1-D restitution collision along the normal; tangential preserved ×0.95 (§5.4).
	var n := event.normal
	var sa := _stats(event.body_a)
	var sb := _stats(event.body_b)
	var va := _vel(event.body_a)
	var vb := _vel(event.body_b)
	var van := va.dot(n)
	var vbn := vb.dot(n)
	var vat := va - van * n
	var vbt := vb - vbn * n
	var ra: float = sa.restitution if sa else Tuning.STATIC_RESTITUTION
	var rb: float = sb.restitution if sb else Tuning.STATIC_RESTITUTION
	var e := (ra + rb) * 0.5   # combination strategy: average (open item §17)
	var m_a: float = sa.mass if sa else INF
	var m_b: float = sb.mass if sb else INF
	var van2: float
	var vbn2: float
	if is_inf(m_b):            # static surface: pure reflection for a
		van2 = -e * van
		vbn2 = vbn
	elif is_inf(m_a):
		vbn2 = -e * vbn
		van2 = van
	else:
		van2 = (m_a * van + m_b * vbn + m_b * e * (vbn - van)) / (m_a + m_b)
		vbn2 = (m_a * van + m_b * vbn + m_a * e * (van - vbn)) / (m_a + m_b)
	var out: Array[Vector2] = [
		vat * Tuning.TANGENT_FRICTION + van2 * n,
		vbt * Tuning.TANGENT_FRICTION + vbn2 * n,
	]
	return out

func _write_back(event: ImpactEvent, new_v: Array[Vector2],
		skip_a: bool, skip_b: bool) -> void:
	# Synthetic events never move the attacker (no recoil).
	if not skip_a and not event.synthetic \
			and event.body_a and event.body_a.has_method("apply_impact_result"):
		event.body_a.apply_impact_result(new_v[0])
	if not skip_b and event.body_b and event.body_b.has_method("apply_impact_result"):
		event.body_b.apply_impact_result(new_v[1])

func _pair_ok(event: ImpactEvent) -> bool:
	if event.bypass_cooldown:
		return true   # parry reflect: a fresh attack on a pair that just collided
	var ia: int = event.body_a.get_instance_id() if event.body_a else 0
	var ib: int = event.body_b.get_instance_id() if event.body_b else 0
	var key := "%d_%d" % [mini(ia, ib), maxi(ia, ib)]
	var now := Time.get_ticks_msec() / 1000.0
	if _pair_times.has(key) and now - _pair_times[key] < Tuning.PAIR_COOLDOWN:
		return false
	_pair_times[key] = now
	# Opportunistic table cleanup to keep it from growing unbounded.
	if _pair_times.size() > 512:
		for k in _pair_times.keys():
			if now - _pair_times[k] > 1.0:
				_pair_times.erase(k)
	return true

func _stats(body: Node) -> PhysicsStats:
	return body.get_stats() if _is_entity(body) else null

func _vel(body: Node) -> Vector2:
	return body.get_impact_velocity() if _is_entity(body) else Vector2.ZERO

func _is_entity(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.has_method("get_stats")
