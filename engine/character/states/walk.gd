class_name FighterWalkState
extends FighterState

## Walking backwards is also blocking: holding back defends when hit, as the 2D
## genre expects. Fighter.is_blocking is what decides that.

var direction: float = 0.0


func physics_update(delta: float) -> void:
	super(delta)
	if handle_grounded_input():
		return
	if fighter.input != null:
		direction = FightInput.horizontal(fighter.input.get_direction())
	fighter.walk(direction)
