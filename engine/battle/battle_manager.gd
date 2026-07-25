class_name BattleManager
extends Node2D

## Dono da partida: instancia os lutadores, define os times e roda o
## CollisionSolver. E o unico lugar que sabe que existem dois lados.
##
## Round, cronometro e placar nao vivem aqui, sao do RoundManager.

signal battle_started()
signal fighter_spawned(fighter: Fighter)
signal fighter_died(fighter: Fighter)
signal hit_resolved(hit: HitData)

const DEFAULT_SPAWN_OFFSET: float = 120.0

@export var fighter_scenes: Array[PackedScene] = []
## Posicoes de spawn. Sem valor para um indice, cai no espelhamento padrao.
@export var spawn_positions: Array[Vector2] = []
@export var start_on_ready: bool = true

var fighters: Array[Fighter] = []
var solver: CollisionSolver


func _ready() -> void:
	solver = CollisionSolver.new()
	solver.name = &"CollisionSolver"
	solver.hit_resolved.connect(_on_hit_resolved)
	add_child(solver)
	if start_on_ready and not fighter_scenes.is_empty():
		start_battle()


## Facing e decidido aqui e nao dentro do lutador: quem sabe quem e o oponente
## de quem e a partida. Golpe comecado nao vira de lado no meio.
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
		push_error("BattleManager: cena %s nao tem um Fighter na raiz" % scene.resource_path)
		return null
	# team antes de entrar na arvore: e ele que define a camada das hurtboxes.
	fighter.team = index
	add_child(fighter)
	fighter.position = get_spawn_position(index)
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


## Liga cada lutador ao adversario e faz os dois se encararem. So pode rodar
## depois de todos estarem na arvore, porque mexe em no de cena do lutador.
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


## Devolve os lutadores para a posicao inicial, encarando o adversario.
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
