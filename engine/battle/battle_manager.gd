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

@export var fighter_scenes: Array[PackedScene] = []
## Spawn positions. Missing entries fall back to the default mirrored offset.
@export var spawn_positions: Array[Vector2] = []
@export var start_on_ready: bool = true
## Registers the keyboard and pad mapping in the InputMap on startup.
@export var apply_input_bindings: bool = true

var fighters: Array[Fighter] = []
var solver: CollisionSolver
var bindings: InputBindings


func _ready() -> void:
	if apply_input_bindings:
		bindings = InputBindings.load_or_create()
		bindings.apply()
	solver = CollisionSolver.new()
	solver.name = &"CollisionSolver"
	solver.hit_resolved.connect(_on_hit_resolved)
	add_child(solver)
	if start_on_ready and not fighter_scenes.is_empty():
		start_battle()


## Facing is decided here and not inside the fighter: knowing who faces whom is
## the match's business. A started attack never flips mid-move.
func _physics_process(_delta: float) -> void:
	for fighter in fighters:
		if fighter.can_turn():
			fighter.update_facing()


func start_battle() -> void:
	clear_battle()
	for index in fighter_scenes.size():
		spawn_fighter(fighter_scenes[index], index)
	pair_fighters()
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
	fighter.died.connect(_on_fighter_died.bind(fighter))


func unregister_fighter(fighter: Fighter) -> void:
	if not fighters.has(fighter):
		return
	fighters.erase(fighter)
	solver.unregister_fighter(fighter)
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


## Sends every fighter back to their starting spot, facing the opponent.
func reset_positions() -> void:
	for index in fighters.size():
		var fighter := fighters[index]
		fighter.position = get_spawn_position(index)
		fighter.velocity = Vector2.ZERO
		fighter.reset_physics_interpolation()
	pair_fighters()


func clear_battle() -> void:
	for fighter in fighters.duplicate():
		solver.unregister_fighter(fighter)
		fighter.queue_free()
	fighters.clear()


func _on_hit_resolved(hit: HitData) -> void:
	hit_resolved.emit(hit)


func _on_fighter_died(fighter: Fighter) -> void:
	fighter_died.emit(fighter)
