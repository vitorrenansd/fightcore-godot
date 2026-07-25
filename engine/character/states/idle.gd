class_name FighterIdleState
extends FighterState


func enter() -> void:
	super()
	fighter.velocity.x = 0.0
