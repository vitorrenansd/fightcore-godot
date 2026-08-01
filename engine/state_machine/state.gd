class_name State
extends Node

signal transitioned(new_state_name: StringName)

var state_frame: int = 0


func enter() -> void:
	state_frame = 0


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	state_frame += 1
