class_name FighterThrowBreakState
extends FighterState

## Two throws reached on the same frame, so neither of them happened.
##
## Both fighters are pushed apart and locked out for the same count. The
## symmetry is the whole rule: if one side recovered first, or came out closer,
## the break would be an exchange somebody won — and the reason a break exists
## is that nobody did. `CollisionSolver` applies the same push to both sides
## without dividing it by weight for the same reason.
##
## The push bleeds off with the fighter's own knockback friction, so a break
## reads like the end of a slide instead of a teleport.

var break_frames: int = 0


## Set before entering. Restarts the count by hand, because `transition_to`
## ignores a transition into the current state and a break can follow a break.
func start_break(frames: int) -> void:
	break_frames = frames
	state_frame = 0


func physics_update(delta: float) -> void:
	super(delta)
	if fighter.is_on_floor() and fighter.stats != null:
		fighter.velocity.x = Knockback.apply_friction(
			fighter.velocity.x, fighter.stats.knockback_friction, delta
		)
	if state_frame >= break_frames:
		transitioned.emit(&"Idle")
