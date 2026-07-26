class_name FighterWakeupState
extends FighterState

## Getting back up.
##
## Invulnerable for the whole rise, and vulnerable again on the exact frame the
## fighter becomes actionable. That single frame is the entire point: it is what
## makes a meaty a real option instead of a free hit, because the attacker has
## to time their active frames to still be running when the body comes back,
## rather than hitting a fighter who cannot answer yet.

func enter() -> void:
	super()
	fighter.hitbox_manager.set_invulnerable(true)
	fighter.velocity.x = 0.0


func exit() -> void:
	super()
	fighter.hitbox_manager.set_invulnerable(false)


func physics_update(delta: float) -> void:
	super(delta)
	if state_frame >= fighter.stats.wakeup_frames:
		transitioned.emit(&"Idle")
