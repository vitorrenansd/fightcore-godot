class_name FighterHitstunState
extends FighterState

var stun_frames: int = 0


## Restarts the count even if the fighter is already in hitstun, which is the
## case for every combo hit after the first.
func start_hitstun(frames: int) -> void:
	stun_frames = frames
	state_frame = 0


func exit() -> void:
	super()
	fighter.reset_combo()


func physics_update(delta: float) -> void:
	super(delta)
	if state_frame >= stun_frames:
		transitioned.emit(&"Idle")
