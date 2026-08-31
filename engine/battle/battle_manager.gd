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
signal throw_broken(first: Fighter, second: Fighter)
## The fight went through a wall and came out in another section.
signal wall_broken(side: int, from_section: int, to_section: int)

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
## Walls the fight happens between. Found in the stage scene when left empty;
## null means an unbounded stage, which is what a hand built test match gets.
@export var stage_bounds: StageBounds
## Registers the keyboard and pad mapping in the InputMap on startup.
@export var apply_input_bindings: bool = true

var fighters: Array[Fighter] = []
var solver: CollisionSolver
var pushboxes: PushboxSolver
var bindings: InputBindings

var _ground_snap_pending: bool = false


func _ready() -> void:
	# Checked where a fight starts, because a fight is what the rate is wrong
	# for. Errors and carries on: the match still runs, it just runs at a speed
	# the frame data was not written for, and that has to be said out loud.
	RoundTimer.verify_tick_rate()
	if apply_input_bindings:
		bindings = InputBindings.load_or_create()
		bindings.apply()
	if stage_bounds == null:
		stage_bounds = find_stage_bounds()
	if stage_bounds != null:
		# Settles the starting section before anyone is spawned into it.
		stage_bounds.reset()
	pushboxes = PushboxSolver.new()
	pushboxes.name = &"PushboxSolver"
	pushboxes.bounds = stage_bounds
	add_child(pushboxes)
	if stage_bounds != null:
		stage_bounds.wall_broken.connect(_on_wall_broken)
	solver = CollisionSolver.new()
	solver.name = &"CollisionSolver"
	solver.hit_resolved.connect(_on_hit_resolved)
	solver.throw_broken.connect(_on_throw_broken)
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


## Spawn columns are read relative to the section the round starts in, so a
## stage with five screens needs no different spawn numbers than one with one.
func get_spawn_position(index: int) -> Vector2:
	var spawn := Vector2(-DEFAULT_SPAWN_OFFSET if index == 0 else DEFAULT_SPAWN_OFFSET, 0.0)
	if index < spawn_positions.size():
		spawn = spawn_positions[index]
	if stage_bounds != null:
		spawn.x += stage_bounds.get_center()
	return spawn


## Distance between the two starting columns. It is the neutral distance, and
## anything that has to put the pair back down somewhere measures from it: a new
## round, and a section they have just broken into.
func get_spawn_separation() -> float:
	return absf(get_spawn_position(0).x - get_spawn_position(1).x)


## Full reset for a new round: health, states and positions.
func reset_round() -> void:
	# Before the positions: the spawn columns are read from the section, so the
	# stage has to be back at its starting one first.
	if stage_bounds != null:
		stage_bounds.reset()
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


func find_stage_bounds() -> StageBounds:
	return StageBounds.find_in(get_parent())


func _on_hit_resolved(hit: HitData) -> void:
	_wear_down_wall(hit)
	hit_resolved.emit(hit)


## A clean hit on a cornered opponent is what wears a wall down.
##
## Blocked ones do not count: the guard already answered the exchange, and a
## wall that fell to chip would make the corner a place you leave by holding
## back. Neither does a hit whose knockback points away from the wall — nothing
## was driven into it.
##
## The amount is the damage the hit actually dealt, scaling included, so a long
## combo wears the wall the same way it wears the fighter: less per hit as it
## goes on.
func _wear_down_wall(hit: HitData) -> void:
	if stage_bounds == null or hit == null or hit.blocked or hit.victim == null:
		return
	var side := _cornered_side(hit.victim, hit.knockback.x)
	if side < 0:
		return
	if stage_bounds.damage_wall(side, hit.damage):
		_go_through_wall(hit.victim, hit.attacker, side)


## Which wall the victim is pinned against, given where the hit pushes them.
## -1 when they have room to be knocked back normally.
func _cornered_side(fighter: Fighter, push_x: float) -> int:
	if is_zero_approx(push_x):
		return -1
	var half := pushboxes.get_pushbox_width(fighter) * 0.5
	var side := StageBounds.Side.RIGHT if push_x > 0.0 else StageBounds.Side.LEFT
	if stage_bounds.is_against_wall(fighter.global_position.x, half, side):
		return side
	return -1


## Both of them come out the other side standing where a round starts: centred
## in the new section, the round's distance apart, the attacker on the side they
## came from and the victim ahead of them.
##
## **Neutral on purpose.** Landing the pair against the edge they broke through
## put the attacker in the corner of the room they had just opened, so winning
## the exchange cost them the space — the opposite of what breaking a wall is
## for. Nobody has earned a side of a section they have only just arrived in, so
## the break gives the ground back to both of them and the fight starts over
## from the middle.
##
## The victim takes the break damage and goes down. That ends the combo on the
## spot, which is the point — the new section opens on a wakeup and not on the
## same pressure carrying straight over.
func _go_through_wall(victim: Fighter, attacker: Fighter, side: int) -> void:
	var direction := StageBounds.side_direction(side)
	var half_gap := get_spawn_separation() * 0.5
	var center := stage_bounds.get_center()
	_place_through_wall(attacker, center - direction * half_gap)
	_place_through_wall(victim, center + direction * half_gap)
	attacker.hitbox_manager.stop_attack()
	attacker.state_machine.transition_to(&"Idle")
	victim.take_damage(stage_bounds.data.wall_break_damage)
	if victim.is_alive():
		victim.state_machine.transition_to(&"Knockdown")
	pair_fighters()


func _place_through_wall(fighter: Fighter, x: float) -> void:
	fighter.global_position.x = x
	fighter.velocity = Vector2.ZERO
	fighter.hitstop_frames = 0
	fighter.reset_physics_interpolation()


func _on_wall_broken(side: int, from_section: int, to_section: int) -> void:
	wall_broken.emit(side, from_section, to_section)


func _on_throw_broken(first: Fighter, second: Fighter) -> void:
	throw_broken.emit(first, second)


func _on_fighter_died(fighter: Fighter) -> void:
	fighter_died.emit(fighter)
