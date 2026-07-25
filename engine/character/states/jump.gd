class_name FighterJumpState
extends FighterState

## Jumps are committed: the direction is read once, on leaving the ground, and
## never changes in the air. That is what makes air spacing mean something.


func enter() -> void:
	super()
	fighter.jump()
	if fighter.input != null:
		var horizontal := FightInput.horizontal(fighter.input.get_direction())
		fighter.velocity.x = horizontal * fighter.stats.walk_speed


func physics_update(delta: float) -> void:
	super(delta)
	fighter.try_command()
	# state_frame > 1 avoids dropping back to Idle on the same frame the jump
	# starts, before vertical velocity lifts the fighter off the floor.
	if state_frame > 1 and fighter.is_on_floor():
		transitioned.emit(&"Idle")
