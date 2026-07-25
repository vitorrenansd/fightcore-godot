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


## Acesso direto a um estado, para quem precisa parametrizar antes de entrar
## nele (hitstun e blockstun recebem a duracao do golpe que acabou de acertar).
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
