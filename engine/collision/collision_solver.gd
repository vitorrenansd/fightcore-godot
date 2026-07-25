class_name CollisionSolver
extends Node

## Resolve os acertos do frame consultando o PhysicsServer direto.
##
## Nada de area_entered nem get_overlapping_areas: sinais de Area2D chegam um
## frame depois e quebram trocas de golpe. Toda hitbox ativa vira uma consulta
## intersect_shape contra a camada de hurtbox do time adversario, no mesmo frame.
##
## Roda com process_physics_priority alto para resolver depois que todos os
## lutadores ja moveram, independente da ordem deles na cena.

const MAX_RESULTS: int = 8
const SOLVE_PRIORITY: int = 100

signal hit_resolved(hit: HitData)

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


## Resolve o frame inteiro: primeiro coleta todos os acertos, so depois aplica.
## Coletar antes e o que permite trade, os dois lados confirmam o golpe antes de
## qualquer um entrar em hitstun ou hitstop.
func solve() -> Array[HitData]:
	var hits: Array[HitData] = []
	for attacker in fighters:
		hits.append_array(_query_fighter(attacker))
	for hit in hits:
		hit.victim.apply_hit(hit)
		hit.attacker.apply_hit_landed(hit)
		hit_resolved.emit(hit)
	return hits


func _query_fighter(attacker: Fighter) -> Array[HitData]:
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
			var hit := _resolve(attacker, attack, hitbox, box_transform.origin, result)
			if hit != null:
				hits.append(hit)
	return hits


func _resolve(
	attacker: Fighter,
	attack: AttackData,
	hitbox: Hitbox,
	hitbox_position: Vector2,
	result: Dictionary
) -> HitData:
	var hurtbox := result.get("collider") as Hurtbox
	if hurtbox == null or not hurtbox.is_active():
		return null

	var victim := hurtbox.fighter
	if victim == null or victim == attacker or not victim.can_be_hit():
		return null
	if not attacker.hitbox_manager.can_hit(victim, hitbox.hit_group):
		return null

	attacker.hitbox_manager.register_hit(victim, hitbox.hit_group)
	var contact := (hitbox_position + hurtbox.global_position) * 0.5
	var blocked := victim.can_block(attack.guard)
	var counter_hit := victim.hitbox_manager.is_in_startup()
	return HitData.build(attack, attacker, victim, contact, blocked, counter_hit)
