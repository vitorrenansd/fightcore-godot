class_name FighterHitstunState
extends FighterState

var stun_frames: int = 0
## Whether the hit that caused this stun puts the fighter on the floor.
var knockdown: bool = false


## Restarts the count even if the fighter is already in hitstun, which is the
## case for every combo hit after the first.
func start_hitstun(frames: int, causes_knockdown: bool = false) -> void:
	stun_frames = frames
	knockdown = causes_knockdown
	state_frame = 0


func exit() -> void:
	super()
	fighter.reset_combo()


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
