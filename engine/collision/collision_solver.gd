class_name CollisionSolver
extends Node

## Resolves this frame's hits by querying the PhysicsServer directly.
##
## No area_entered, no get_overlapping_areas: Area2D signals arrive a frame
## late and break trades. Every active hitbox becomes an intersect_shape query
## against the opposing team's hurtbox layer, on the same frame.
##
## Runs with a high process_physics_priority so it resolves after every fighter
## has moved, no matter their order in the scene.

const MAX_RESULTS: int = 8
const SOLVE_PRIORITY: int = 100

signal hit_resolved(hit: HitData)
## A throw reached someone who was throwing back: neither one happened.
signal throw_broken(first: Fighter, second: Fighter)

var fighters: Array[Fighter] = []

var _query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	process_physics_priority = SOLVE_PRIORITY
	_query.collide_with_areas = true
	_query.collide_with_bodies = false


func _physics_process(_delta: float) -> void:
	solve()


func register_fighter(fighter: Fighter) -> void:
	if fighter != null and not fighters.has(fighter):
		fighters.append(fighter)


func unregister_fighter(fighter: Fighter) -> void:
	fighters.erase(fighter)


## Resolves the whole frame: collects every hit first, applies them afterwards.
## Collecting first is what allows trades — both sides confirm their hit before
## either one enters hitstun or hitstop.
##
## Throw breaks are collected the same way and applied last. Both sides of a
## break already know about each other by then, so the two fighters can never
## disagree about whether the exchange happened.
func solve() -> Array[HitData]:
	var hits: Array[HitData] = []
	var breaks: Array[Array] = []
	for attacker in fighters:
		hits.append_array(_query_fighter(attacker, breaks))
	for hit in hits:
		hit.victim.apply_hit(hit)
		hit.attacker.apply_hit_landed(hit)
		if hit.attack.throw_side_switch:
			_switch_sides(hit.attacker, hit.victim)
		hit_resolved.emit(hit)
	for pair in breaks:
		_apply_throw_break(pair[0], pair[1], pair[2])
	return hits


func _query_fighter(attacker: Fighter, breaks: Array[Array]) -> Array[HitData]:
	var hits: Array[HitData] = []
	if not attacker.can_resolve_hits():
		return hits

	var manager := attacker.hitbox_manager
	var attack := manager.current_attack
	var space := attacker.get_world_2d().direct_space_state
	for hitbox in manager.get_active_hitboxes():
		var box_transform := hitbox.get_query_transform(attacker.global_position, attacker.facing_right)
		_query.shape = hitbox.shape
		_query.transform = box_transform
		_query.collision_mask = CollisionLayers.opponent_hurtbox_mask(attacker.team)
		for result in space.intersect_shape(_query, MAX_RESULTS):
			var hit := _resolve(attacker, attack, hitbox, box_transform.origin, result, breaks)
			if hit != null:
				hits.append(hit)
	return hits


func _resolve(
	attacker: Fighter,
	attack: AttackData,
	hitbox: Hitbox,
	hitbox_position: Vector2,
	result: Dictionary,
	breaks: Array[Array]
) -> HitData:
	var hurtbox := result.get("collider") as Hurtbox
	if hurtbox == null or not hurtbox.is_active():
		return null

	var victim := hurtbox.fighter
	if victim == null or victim == attacker or not victim.can_be_hit():
		return null
	if not attacker.hitbox_manager.can_hit(victim, hitbox.hit_group):
		return null

	if attack.is_throw:
		# Neither outcome is a hit, so neither registers one: a whiffed grab has
		# to be free to catch the same opponent on a later active frame.
		if victim.is_teching_throw():
			_record_throw_break(breaks, attacker, victim, attack)
			return null
		if not victim.can_be_thrown():
			return null

	attacker.hitbox_manager.register_hit(victim, hitbox.hit_group)
	var contact := (hitbox_position + hurtbox.global_position) * 0.5
	var blocked := victim.can_block(attack.guard)
	var counter_hit := victim.hitbox_manager.is_in_startup()
	return HitData.build(attack, attacker, victim, contact, blocked, counter_hit)


## Trades the two fighters' columns. Only `x`: the throw catches a grounded
## opponent, so there is no height to preserve, and moving `y` would drop a
## fighter through the floor the snap already settled them on.
##
## Both are looking the wrong way afterwards and neither can fix it — the
## attacker is mid-move and the victim is in hitstun, and `can_turn()` refuses
## both — so the facing is set here along with the position.
func _switch_sides(attacker: Fighter, victim: Fighter) -> void:
	var attacker_x := attacker.global_position.x
	attacker.global_position.x = victim.global_position.x
	victim.global_position.x = attacker_x
	attacker.set_facing(victim.global_position.x > attacker.global_position.x)
	victim.set_facing(attacker.global_position.x > victim.global_position.x)
	# The swap is a jump, not a movement. Without this the renderer interpolates
	# from the old column and both fighters smear across the screen.
	attacker.reset_physics_interpolation()
	victim.reset_physics_interpolation()


## One entry per pair. Two grabs reaching each other on the same frame find each
## other twice, and a wide throw with several boxes finds the same pair once per
## box, but a break is one event either way.
func _record_throw_break(
	breaks: Array[Array], attacker: Fighter, victim: Fighter, attack: AttackData
) -> void:
	for pair in breaks:
		if (pair[0] == attacker and pair[1] == victim) or (pair[0] == victim and pair[1] == attacker):
			return
	breaks.append([attacker, victim, attack])


## Pushes both fighters apart by the same amount, away from each other.
func _apply_throw_break(first: Fighter, second: Fighter, attack: AttackData) -> void:
	var away := signf(first.global_position.x - second.global_position.x)
	# Standing in exactly the same column: the facing breaks the tie, the way the
	# pushbox solver does it.
	if is_zero_approx(away):
		away = -1.0 if first.facing_right else 1.0
	first.break_throw(attack, away)
	second.break_throw(attack, -away)
	throw_broken.emit(first, second)
