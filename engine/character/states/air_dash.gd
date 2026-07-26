class_name FighterAirDashState
extends FighterState

## Horizontal burst in the air, with gravity suspended for the duration.
##
## Suspending gravity is what makes the dash read as a straight line instead of
## a shallow jump, and what makes it useful to close distance or to bait an
## anti-air. It costs one of the fighter's air dashes, which only come back on
## landing — otherwise a fighter could stay airborne forever.
##
## Attacks come out of a dash: that is the whole point of dashing in.

## Direction in fighter space: 1 forward, -1 back.
var direction: float = 1.0


func setup(relative_direction: float) -> void:
	direction = relative_direction


func enter() -> void:
	super()
	fighter.air_dashes_left -= 1
	fighter.gravity_enabled = false
	var facing := 1.0 if fighter.facing_right else -1.0
	fighter.velocity = Vector2(direction * facing * fighter.stats.air_dash_speed, 0.0)


func exit() -> void:
	super()
	fighter.gravity_enabled = true


func physics_update(delta: float) -> void:
	super(delta)
	if fighter.try_command():
		return
	if fighter.is_on_floor():
		transitioned.emit(&"Idle")
		return
	# Momentum is kept on the way out: the fighter falls out of the dash still
	# moving, instead of stopping dead in the air.
	if state_frame >= fighter.stats.air_dash_frames:
		transitioned.emit(&"Jump")
