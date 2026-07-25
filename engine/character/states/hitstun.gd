class_name FighterHitstunState
extends FighterState

var stun_frames: int = 0


## Reinicia a contagem mesmo se o lutador ja estiver em hitstun, que e o caso de
## todo hit de combo depois do primeiro.
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
