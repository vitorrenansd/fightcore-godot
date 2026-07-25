class_name FighterBlockState
extends FighterState

## Guarda em pe ou abaixada, e tambem o blockstun. Enquanto stun_frames for 0 o
## lutador esta apenas segurando a guarda e pode sair quando quiser.
var crouch_block: bool = false
var stun_frames: int = 0


func enter() -> void:
	super()
	fighter.velocity.x = 0.0


func exit() -> void:
	super()
	stun_frames = 0


## Prende o lutador na guarda pelos frames do golpe defendido.
func start_blockstun(frames: int, crouching: bool) -> void:
	stun_frames = frames
	crouch_block = crouching
	state_frame = 0


func is_in_blockstun() -> bool:
	return stun_frames > 0 and state_frame < stun_frames


func physics_update(delta: float) -> void:
	super(delta)
	if stun_frames > 0 and state_frame >= stun_frames:
		stun_frames = 0
		transitioned.emit(&"Idle")
