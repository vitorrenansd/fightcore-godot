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
## The stage walls are resolved here too, and for the same reason: keeping a
## fighter inside the stage and keeping two fighters apart are one constraint,
## not two. Solving them separately means the wall clamp undoes the separation
## or the separation pushes someone through the wall, depending on which ran
## last.
##
## Runs before the hit solver so hitbox queries see final positions.

const SOLVE_PRIORITY: int = 90
## Cap per fighter per frame, so landing fully overlapped separates over a few
## frames instead of teleporting both apart.
const MAX_PUSH_PER_FRAME: float = 6.0

var fighters: Array[Fighter] = []
## Walls the fighters are kept between. Null leaves the stage unbounded, which
## is what every test that builds its own match gets.
var bounds: StageBounds


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
	# Walls first: separation reads the room each fighter has left, and it can
	# only read that once everyone is inside the stage.
	_clamp_to_walls()
	for index in fighters.size():
		for other in range(index + 1, fighters.size()):
			_separate(fighters[index], fighters[other])


## Keeps every fighter between the walls, airborne ones included: a jump that
## carried on past the corner would leave the stage.
func _clamp_to_walls() -> void:
	if bounds == null:
		return
	for fighter in fighters:
		var half := get_pushbox_width(fighter) * 0.5
		var clamped := bounds.clamp_x(fighter.global_position.x, half)
		if is_equal_approx(clamped, fighter.global_position.x):
			continue
		# Only the component pointing into the wall goes. Zeroing the whole
		# thing would eat the knockback of a hit that sends them back out.
		if clamped < fighter.global_position.x:
			fighter.velocity.x = minf(fighter.velocity.x, 0.0)
		else:
			fighter.velocity.x = maxf(fighter.velocity.x, 0.0)
		fighter.global_position.x = clamped


## Room `fighter` has before the wall in `direction`, or all of it when the
## stage has no walls.
func get_room(fighter: Fighter, direction: float) -> float:
	if bounds == null:
		return INF
	return bounds.get_room(
		fighter.global_position.x, get_pushbox_width(fighter) * 0.5, direction
	)


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

	var share := minf(overlap * 0.5, MAX_PUSH_PER_FRAME)
	var a_room := get_room(a, -direction)
	var b_room := get_room(b, direction)
	var a_push := minf(share, a_room)
	var b_push := minf(share, b_room)
	# What one of them cannot give, the other takes. A fighter with their back
	# to the wall has no ground left, so the whole separation goes into the
	# opponent instead of half of it — which is the entire reason cornering
	# someone is worth doing. The per frame cap still holds on both sides.
	var refused := (share - a_push) + (share - b_push)
	a_push = minf(a_push + refused, minf(a_room, MAX_PUSH_PER_FRAME))
	b_push = minf(b_push + refused, minf(b_room, MAX_PUSH_PER_FRAME))
	a.global_position.x -= a_push * direction
	b.global_position.x += b_push * direction


func get_pushbox_width(fighter: Fighter) -> float:
	return fighter.stats.pushbox_width if fighter.stats != null else 0.0
