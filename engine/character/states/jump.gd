class_name FighterJumpState
extends FighterState


func enter() -> void:
	super()
	fighter.jump()


func physics_update(delta: float) -> void:
	super(delta)
	if fighter.is_on_floor():
		transitioned.emit(&"Idle")
