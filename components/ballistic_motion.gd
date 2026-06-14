class_name BallisticMotion
extends Node
## The actor physics state machine (GDD §4.1). Owns velocity write-back
## from the resolver. The owning CharacterBody2D calls physics_update()
## every physics tick with its movement intent.

enum State { GROUNDED, BALLISTIC, STUNNED }

signal launched(velocity: Vector2)
signal landed

var state := State.GROUNDED
var ballistic_velocity := Vector2.ZERO
var soft_knockback := Vector2.ZERO
var stun_time := Tuning.STUN_TIME_DEFAULT
var _stun_timer := 0.0

var _body: CharacterBody2D
var _stats: PhysicsStats

func setup(body: CharacterBody2D, stats: PhysicsStats) -> void:
	_body = body
	_stats = stats

func is_controllable() -> bool:
	return state == State.GROUNDED

## Drive the body. intent = authored movement (input/AI); ignored unless GROUNDED.
func physics_update(intent: Vector2, delta: float) -> void:
	match state:
		State.GROUNDED:
			soft_knockback *= exp(-Tuning.SOFT_KNOCKBACK_DECAY * delta)
			_body.velocity = intent + soft_knockback
			_body.move_and_slide()
		State.BALLISTIC:
			ballistic_velocity *= maxf(0.0, 1.0 - _stats.drag * delta)
			var col := _body.move_and_collide(ballistic_velocity * delta)
			if col:
				# Resolver computes reflection + damage and writes our new
				# velocity back through apply_impact_result → set_velocity().
				ImpactResolver.resolve_kinematic(get_parent(), col, ballistic_velocity)
			if ballistic_velocity.length() < Tuning.REST_SPEED:
				_enter_stunned()
		State.STUNNED:
			_body.velocity = Vector2.ZERO
			_stun_timer -= delta
			if _stun_timer <= 0.0:
				state = State.GROUNDED
				landed.emit()

func current_velocity() -> Vector2:
	return ballistic_velocity if state == State.BALLISTIC else _body.velocity

## Resolver write-back. Decides GROUNDED-with-soft-knockback vs BALLISTIC (§5.4).
func apply_impact_result(new_velocity: Vector2) -> void:
	if state == State.BALLISTIC:
		ballistic_velocity = new_velocity
		if ballistic_velocity.length() < Tuning.REST_SPEED:
			_enter_stunned()
	elif new_velocity.length() > _stats.launch_speed:
		launch(new_velocity)
	else:
		# Sub-threshold: add the delta-v to the decaying soft knockback —
		# this is the orc's "slight knockback".
		soft_knockback += new_velocity - _body.velocity

func launch(velocity: Vector2) -> void:
	state = State.BALLISTIC
	ballistic_velocity = velocity
	launched.emit(velocity)

func _enter_stunned() -> void:
	state = State.STUNNED
	ballistic_velocity = Vector2.ZERO
	soft_knockback = Vector2.ZERO
	_stun_timer = stun_time
