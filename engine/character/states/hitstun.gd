class_name FighterHitstunState
extends FighterState

var stun_frames: int = 0
## Whether the hit that caused this stun puts the fighter on the floor.
var knockdown: bool = false


## Restarts the count even if the fighter is already in hitstun, which is the
## case for every combo hit after the first.
##
## The knockdown accumulates instead of being replaced. A throw or a sweep says
## this combo ends on the floor, and a jab picked up afterwards cannot take that
## back: without the `or`, `6D > 5P` would hand the victim back standing, as if
## the throw had never happened.
func start_hitstun(frames: int, causes_knockdown: bool = false) -> void:
	stun_frames = frames
	knockdown = knockdown or causes_knockdown
	state_frame = 0


func exit() -> void:
	super()
	fighter.reset_combo()
	# The combo is over, so the next one starts owing nothing.
	knockdown = false


func physics_update(delta: float) -> void:
	super(delta)
	if state_frame < stun_frames:
		return
	# Airborne always means down. There is no air recovery, so handing control
	# back mid-air would let the victim escape a combo for free — and would give
	# the route no ending at all.
	if not fighter.is_on_floor() or knockdown:
		transitioned.emit(&"Knockdown")
		return
	transitioned.emit(&"Idle")
