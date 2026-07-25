class_name FighterHitstunState
extends FighterState

var stun_frames: int = 0


func physics_update(delta: float) -> void:
	super(delta)
	if state_frame >= stun_frames:
		transitioned.emit(&"Idle")
