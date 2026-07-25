class_name FighterIdleState
extends FighterState


func enter() -> void:
	super()
	fighter.velocity.x = 0.0


func physics_update(delta: float) -> void:
	super(delta)
	handle_grounded_input()
