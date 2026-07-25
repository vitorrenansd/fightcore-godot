class_name FighterWalkState
extends FighterState

var direction: float = 0.0


func physics_update(delta: float) -> void:
	super(delta)
	fighter.walk(direction)
