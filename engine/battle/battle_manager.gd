class_name BattleManager
extends Node2D

## Owner of the match: spawns the fighters, assigns teams and runs the
## CollisionSolver. The only place in the engine that knows there are two sides.
##
## Rounds, timer and score do **not** live here — those belong to RoundManager.

signal battle_started()
signal fighter_spawned(fighter: Fighter)
signal fighter_died(fighter: Fighter)
signal hit_resolved(hit: HitData)

const DEFAULT_SPAWN_OFFSET: float = 120.0

## How far a spawn column is searched for the stage floor. A query bound only —
## the ground height itself is whatever the fighter lands on, never a number
## written down here or in the stage.
const GROUND_SEARCH: float = 4000.0

## Casts used to settle a fighter on the floor. Four is well past convergence;
## see `snap_to_ground` for why one is not enough.
const GROUND_SNAP_PASSES: int = 4

@export var fighter_scenes: Array[PackedScene] = []
## Spawn positions. `x` is the starting column; `y` is measured **from the
## stage floor**, so `0` puts the fighter on the ground and a negative value
## starts them that far above it. Missing entries fall back to the default
## mirrored offset.
@export var spawn_positions: Array[Vector2] = []
@export var start_on_ready: bool = true
## Registers the keyboard and pad mapping in the InputMap on startup.
@export var apply_input_bindings: bool = true

var fighters: Array[Fighter] = []
var solver: CollisionSolver
var pushboxes: PushboxSolver
var bindings: InputBindings

var _ground_snap_pending: bool = false


func _ready() -> void:
	if apply_input_bindings:
		bindings = InputBindings.load_or_create()
		bindings.apply()
	pushboxes = PushboxSolver.new()
	pushboxes.name = &"PushboxSolver"
	add_child(pushboxes)
	solver = CollisionSolver.new()
	solver.name = &"CollisionSolver"
	solver.hit_resolved.connect(_on_hit_resolved)
	add_child(solver)
	if start_on_ready and not fighter_scenes.is_empty():
		start_battle()


## Facing is decided here and not inside the fighter: knowing who faces whom is
## the match's business. A started attack never flips mid-move.
func _physics_process(_delta: float) -> void:
	if _ground_snap_pending:
		# One retry, no more. A round set up from `_ready` asks the physics
		# space a question it cannot answer yet, and by the first physics frame
		# it can. Whatever still fails has no floor under it, and asking again
		# every frame would not change that.
		_ground_snap_pending = false
		snap_fighters_to_ground()
	for fighter in fighters:
		if fighter.can_turn():
			fighter.update_facing()


func start_battle() -> void:
	clear_battle()
	for index in fighter_scenes.size():
		spawn_fighter(fighter_scenes[index], index)
	reset_positions()
	battle_started.emit()


func spawn_fighter(scene: PackedScene, index: int) -> Fighter:
	var fighter := scene.instantiate() as Fighter
	if fighter == null:
		push_error("BattleManager: scene %s has no Fighter at its root" % scene.resource_path)
		return null
	# team before entering the tree: it decides the hurtbox layer.
	fighter.team = index
	add_child(fighter)
	fighter.position = get_spawn_position(index)
	# Team 0 plays on p1_*, team 1 on p2_*.
	if fighter.input != null:
		fighter.input.player_index = index
	register_fighter(fighter)
	fighter_spawned.emit(fighter)
	return fighter


func register_fighter(fighter: Fighter) -> void:
	if fighter == null or fighters.has(fighter):
		return
	fighters.append(fighter)
	solver.register_fighter(fighter)
	pushboxes.register_fighter(fighter)
	fighter.died.connect(_on_fighter_died.bind(fighter))


func unregister_fighter(fighter: Fighter) -> void:
	if not fighters.has(fighter):
		return
	fighters.erase(fighter)
	solver.unregister_fighter(fighter)
	pushboxes.unregister_fighter(fighter)
	var callback := _on_fighter_died.bind(fighter)
	if fighter.died.is_connected(callback):
		fighter.died.disconnect(callback)


## Links each fighter to their opponent and makes both face each other. Only
## valid once everyone is in the tree, since it touches fighter scene nodes.
func pair_fighters() -> void:
	for fighter in fighters:
		fighter.opponent = get_opponent_of(fighter)
		fighter.update_facing()


func get_opponent_of(fighter: Fighter) -> Fighter:
	for other in fighters:
		if other != fighter and other.team != fighter.team:
			return other
	return null


func get_fighter(team: int) -> Fighter:
	for fighter in fighters:
		if fighter.team == team:
			return fighter
	return null


func get_spawn_position(index: int) -> Vector2:
	if index < spawn_positions.size():
		return spawn_positions[index]
	return Vector2(-DEFAULT_SPAWN_OFFSET if index == 0 else DEFAULT_SPAWN_OFFSET, 0.0)


## Full reset for a new round: health, states and positions.
func reset_round() -> void:
	for fighter in fighters:
		fighter.reset_for_round()
	reset_positions()


## Freezes or releases every fighter, used by the round intro and pauses.
func set_fighters_frozen(frozen: bool) -> void:
	for fighter in fighters:
		fighter.frozen = frozen


## Sends every fighter back to their starting spot, standing on the ground and
## facing the opponent.
func reset_positions() -> void:
	for index in fighters.size():
		var fighter := fighters[index]
		fighter.position = get_spawn_position(index)
		fighter.velocity = Vector2.ZERO
		fighter.reset_physics_interpolation()
	_ground_snap_pending = not snap_fighters_to_ground()
	pair_fighters()


## Puts every fighter on the stage floor. Returns false when the physics space
## could not answer for at least one of them, so the caller can try again.
func snap_fighters_to_ground() -> bool:
	var settled := true
	for fighter in fighters:
		if not snap_to_ground(fighter):
			settled = false
	return settled


## Drops `fighter` straight down onto whatever the stage puts under them and
## re-applies the spawn height as a distance above it.
##
## The drop is a shape cast with the fighter's own collision shape, which is
## the point: a taller character, a different stage floor or a stage with two
## levels all work with no height written anywhere. Authoring the ground as a
## number would mean every stage and every character agreeing on it forever.
##
## A fighter is not standing on anything until a `move_and_slide()` says so, so
## the snap ends with one. Without it `is_on_floor()` stays false through the
## whole intro freeze and only turns true a frame into the round, which is a
## frame of the round spent airborne on the ground.
func snap_to_ground(fighter: Fighter) -> bool:
	var spawn := fighter.position
	# Search from well above the column so the cast starts clear of the floor
	# even when the spawn height is authored below it.
	fighter.position = Vector2(spawn.x, spawn.y - GROUND_SEARCH)
	var reach := GROUND_SEARCH * 2.0
	var landed := false
	for _pass in GROUND_SNAP_PASSES:
		var landing := fighter.move_and_collide(Vector2(0.0, reach), true)
		if landing == null:
			break
		landed = true
		fighter.position += landing.get_travel()
		# A long cast stops short of the surface by roughly its own length over
		# 768: `body_test_motion` binary-searches the motion instead of solving
		# it, so 8000px of search leaves a 10px gap. Re-casting a short distance
		# from where the last one stopped closes that gap geometrically, and
		# the next reach is always far wider than the error left behind.
		reach = maxf(reach / 64.0, 0.01)
	if not landed:
		fighter.position = spawn
		return false
	fighter.position += Vector2(0.0, spawn.y)
	# Establishes floor contact. Zero velocity, so it settles the fighter
	# without moving them off the spot the cast just found.
	fighter.velocity = Vector2.ZERO
	fighter.move_and_slide()
	fighter.reset_physics_interpolation()
	return true


func clear_battle() -> void:
	for fighter in fighters.duplicate():
		solver.unregister_fighter(fighter)
		pushboxes.unregister_fighter(fighter)
		fighter.queue_free()
	fighters.clear()


func _on_hit_resolved(hit: HitData) -> void:
	hit_resolved.emit(hit)


func _on_fighter_died(fighter: Fighter) -> void:
	fighter_died.emit(fighter)
