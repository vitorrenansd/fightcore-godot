class_name FighterState
extends State

@onready var fighter: Fighter = owner as Fighter


## Handles input for a grounded state: command first, movement second.
## True when the state changed, in which case the caller must stop here.
##
## Attacks come before walking on purpose: pressing 6P must not turn into a
## single step forward.
func handle_grounded_input() -> bool:
	if fighter.try_command():
		return true
	var target := get_grounded_state()
	if target == name:
		return false
	transitioned.emit(target)
	return true


## State the currently held direction is asking for.
func get_grounded_state() -> StringName:
	if fighter.input == null:
		return &"Idle"
	var direction := fighter.input.get_direction()
	if FightInput.is_up(direction):
		return &"Jump"
	if FightInput.is_down(direction):
		return &"Crouch"
	if FightInput.horizontal(direction) != 0:
		return &"Walk"
	return &"Idle"
