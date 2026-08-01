class_name FighterKnockdownState
extends FighterState

## The fighter is down: falls out of the combo, hits the floor, and lies there
## for a fixed count before getting up.
##
## This is what an air combo ends in. Before it existed, hitstun running out in
## the air handed control straight back and the route had no terminator.
##
## The airborne half stays **vulnerable** on purpose — that is the juggle window,
## and it is juggle gravity that decides when the fall stops being extendable.
## The grounded half goes invulnerable and stays that way through `Wakeup`, so a
## knockdown cannot be looped into another one while the victim lies there.

## Frames spent lying on the floor, counted from 1 on the first grounded frame.
var _ground_frame: int = 0
var _grounded: bool = false


func enter() -> void:
	super()
	fighter.hitbox_manager.stop_attack()
	_ground_frame = 0
	_grounded = false


func exit() -> void:
	super()
	fighter.hitbox_manager.set_invulnerable(false)


func physics_update(delta: float) -> void:
	super(delta)
	if not fighter.is_on_floor():
		return
	if not _grounded:
		# First frame on the floor: the body goes off and the count starts.
		_grounded = true
		fighter.hitbox_manager.set_invulnerable(true)
	fighter.velocity.x = 0.0
	_ground_frame += 1
	if _ground_frame >= fighter.stats.knockdown_frames:
		transitioned.emit(&"Wakeup")


## Frames already spent lying down, for the HUD and for tests. Zero while the
## fighter is still falling.
func get_ground_frame() -> int:
	return _ground_frame
