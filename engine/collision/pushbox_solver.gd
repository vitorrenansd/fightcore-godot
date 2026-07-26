class_name PushboxSolver
extends Node

## Keeps fighters from occupying the same space, without ever letting one stand
## on the other.
##
## Fighters are not physics obstacles to each other: their bodies only collide
## with the stage. If they collided as bodies, landing on an opponent's head
## would leave both stuck there, and neither could be hit. Separation is done
## here instead, and it is **horizontal only**.
##
## The push is skipped while either fighter is airborne, which is what lets a
## jump pass over the opponent and land on the other side. Crossups exist
## because of this rule.
##
## Runs before the hit solver so hitbox queries see final positions.

const SOLVE_PRIORITY: int = 90
## Cap per fighter per frame, so landing fully overlapped separates over a few
## frames instead of teleporting both apart.
const MAX_PUSH_PER_FRAME: float = 6.0

var fighters: Array[Fighter] = []


func _ready() -> void:
	process_physics_priority = SOLVE_PRIORITY


func _physics_process(_delta: float) -> void:
	solve()


func register_fighter(fighter: Fighter) -> void:
	if fighter != null and not fighters.has(fighter):
		fighters.append(fighter)


func unregister_fighter(fighter: Fighter) -> void:
	fighters.erase(fighter)


func solve() -> void:
	for index in fighters.size():
		for other in range(index + 1, fighters.size()):
			_separate(fighters[index], fighters[other])


func _separate(a: Fighter, b: Fighter) -> void:
	# Airborne fighters pass straight through each other.
	if not a.is_on_floor() or not b.is_on_floor():
		return
	if not a.is_alive() or not b.is_alive():
		return

	var half_width := (get_pushbox_width(a) + get_pushbox_width(b)) * 0.5
	var delta := b.global_position.x - a.global_position.x
	var overlap := half_width - absf(delta)
	if overlap <= 0.0:
		return

	# Exactly on top of each other: break the tie with the facing.
	var direction := signf(delta)
	if is_zero_approx(direction):
		direction = 1.0 if a.facing_right else -1.0

	var push := minf(overlap * 0.5, MAX_PUSH_PER_FRAME)
	a.global_position.x -= push * direction
	b.global_position.x += push * direction


func get_pushbox_width(fighter: Fighter) -> float:
	return fighter.stats.pushbox_width if fighter.stats != null else 0.0
