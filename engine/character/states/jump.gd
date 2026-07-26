class_name FighterJumpState
extends FighterState

## Doubles as the airborne state: entering it from the ground jumps, entering it
## from the air (after an air attack, after hitstun) just means "still falling".
##
## The jump is committed: the direction is read once, on leaving the ground, and
## never changes in the air. Air jumps and air dashes are the only ways to
## change where the fighter is going, and both are spent until landing.

## The press that started the jump must not also spend the air jump, so up has
## to be released before a second jump counts.
var _needs_up_release: bool = true


func enter() -> void:
	super()
	_needs_up_release = true
	if not fighter.is_on_floor():
		return
	fighter.jump()
	if fighter.input != null:
		var horizontal := FightInput.horizontal(fighter.input.get_direction())
		fighter.velocity.x = horizontal * fighter.stats.walk_speed


func physics_update(delta: float) -> void:
	super(delta)
	if fighter.input != null and not fighter.input.is_holding_up():
		_needs_up_release = false
	if fighter.try_command():
		return
	if _try_air_dash():
		return
	_try_air_jump()
	# state_frame > 1 avoids dropping back to Idle on the same frame the jump
	# starts, before vertical velocity lifts the fighter off the floor.
	if state_frame > 1 and fighter.is_on_floor():
		transitioned.emit(&"Idle")


func _try_air_dash() -> bool:
	if fighter.input == null or not fighter.can_air_dash():
		return false
	var forward := fighter.input.has_dash_input(true, fighter.facing_right)
	if not forward and not fighter.input.has_dash_input(false, fighter.facing_right):
		return false
	var state := fighter.state_machine.get_state(&"AirDash") as FighterAirDashState
	if state == null:
		return false
	state.setup(1.0 if forward else -1.0)
	fighter.state_machine.transition_to(&"AirDash")
	return true


## A second jump restarts the arc, so state_frame goes back to zero with it.
func _try_air_jump() -> bool:
	if fighter.input == null or _needs_up_release or not fighter.can_air_jump():
		return false
	if not fighter.input.was_up_pressed():
		return false
	if not fighter.air_jump():
		return false
	_needs_up_release = true
	state_frame = 0
	return true
