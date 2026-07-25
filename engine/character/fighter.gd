class_name Fighter
extends CharacterBody2D

@export var fighter_data: FighterData

var opponent: Fighter
var facing_right: bool = true

@onready var visuals: Node2D = $Visuals


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += fighter_data.stats.gravity * delta


func walk(direction: float) -> void:
	velocity.x = direction * fighter_data.stats.walk_speed


func jump() -> void:
	if is_on_floor():
		velocity.y = fighter_data.stats.jump_velocity


func update_facing() -> void:
	if opponent == null:
		return
	set_facing(opponent.global_position.x > global_position.x)


func set_facing(face_right: bool) -> void:
	if facing_right == face_right:
		return
	facing_right = face_right
	visuals.scale.x = 1.0 if face_right else -1.0
