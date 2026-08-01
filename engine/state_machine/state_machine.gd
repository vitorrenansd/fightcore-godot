class_name StateMachine
extends Node

@export var initial_state_name: StringName = &"Idle"

var current_state: State
var states: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.transitioned.connect(transition_to)
	transition_to(initial_state_name)


## Direct access to a state, for callers that need to parametrize it before
## entering (hitstun and blockstun take the duration of the move that just hit).
func get_state(state_name: StringName) -> State:
	return states.get(state_name)


func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(state_name: StringName) -> void:
	if not states.has(state_name):
		return
	if current_state == states[state_name]:
		return
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter()
