class_name FighterBlockState
extends FighterState

## Blockstun. Blocking itself is not a state: holding back is what defends
## (see Fighter.is_blocking). This state only exists to lock the fighter for
## the blockstun of the move that was just guarded.

var crouch_block: bool = false
var stun_frames: int = 0


func enter() -> void:
	super()
	fighter.velocity.x = 0.0


func exit() -> void:
	super()
	stun_frames = 0


## Locks the fighter in guard for the blocked move's frames.
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
