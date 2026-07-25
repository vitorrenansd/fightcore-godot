class_name Fighter
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal hit_taken(hit: HitData)
signal hit_landed(hit: HitData)
signal died()

@export var fighter_data: FighterData
## Lado do lutador. Define a camada das hurtboxes e quem ele consegue acertar.
@export var team: int = 0

var opponent: Fighter
var facing_right: bool = true
var health: int = 0
## Golpes ja levados no combo atual, base do escalonamento de dano.
var combo_hits: int = 0
## Frames de congelamento restantes do impacto.
var hitstop_frames: int = 0

var stats: FighterStats:
	get:
		return fighter_data.stats if fighter_data != null else null

@onready var visuals: Node2D = $Visuals
@onready var state_machine: FighterStateMachine = $StateMachine
@onready var hitbox_manager: HitboxManager = $HitboxManager


func _ready() -> void:
	hitbox_manager.setup(self)
	health = stats.max_health if stats != null else 0
	health_changed.emit(health, health)


func _physics_process(delta: float) -> void:
	if hitstop_frames > 0:
		hitstop_frames -= 1
		return
	hitbox_manager.advance()
	state_machine.physics_update(delta)
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += stats.gravity * delta


func walk(direction: float) -> void:
	velocity.x = direction * stats.walk_speed


func jump() -> void:
	if is_on_floor():
		velocity.y = stats.jump_velocity


func update_facing() -> void:
	if opponent == null:
		return
	set_facing(opponent.global_position.x > global_position.x)


func set_facing(face_right: bool) -> void:
	if facing_right == face_right:
		return
	facing_right = face_right
	visuals.scale.x = 1.0 if face_right else -1.0
	hitbox_manager.set_facing(face_right)


## Aplica o resultado de um acerto recebido. Chamado pelo CollisionSolver.
func apply_hit(hit: HitData) -> void:
	health = maxi(health - hit.damage, 0)
	apply_hitstop(hit.hitstop)
	if health == 0:
		_enter_ko()
	elif hit.blocked:
		_enter_blockstun(hit)
	else:
		combo_hits += 1
		_enter_hitstun(hit)
	# Depois da transicao: entrar em um estado zera a velocidade horizontal.
	velocity = hit.knockback
	health_changed.emit(health, stats.max_health if stats != null else health)
	hit_taken.emit(hit)
	if health == 0:
		died.emit()


## Contrapartida no atacante: hitstop e aviso de hit confirm.
func apply_hit_landed(hit: HitData) -> void:
	apply_hitstop(hit.hitstop)
	hit_landed.emit(hit)


func apply_hitstop(frames: int) -> void:
	hitstop_frames = maxi(hitstop_frames, frames)


func reset_combo() -> void:
	combo_hits = 0


func is_alive() -> bool:
	return health > 0


## Alvo valido para as consultas do solver.
func can_be_hit() -> bool:
	return is_alive()


## Atacante valido no frame atual. Quem esta congelado nao confirma golpe novo.
func can_resolve_hits() -> bool:
	return is_alive() and hitstop_frames == 0 and hitbox_manager.is_attacking()


## Executa um golpe. Falso quando o lutador nao pode agir no momento.
func perform_attack(attack: AttackData) -> bool:
	if attack == null or not can_act():
		return false
	var state := state_machine.get_state(&"Attack") as FighterAttackState
	if state == null:
		return false
	state.setup(attack)
	state_machine.transition_to(&"Attack")
	return true


func perform_attack_by_id(attack_id: StringName) -> bool:
	return perform_attack(get_attack(attack_id))


func get_attack(attack_id: StringName) -> AttackData:
	if fighter_data == null:
		return null
	for attack in fighter_data.moves:
		if attack != null and attack.attack_id == attack_id:
			return attack
	return null


## Livre para receber comando. Congelado ou preso em stun nao aceita nada.
func can_act() -> bool:
	return is_alive() and hitstop_frames == 0 and not is_in_stun()


## Pode virar de lado. Golpe comecado nao troca de lado no meio.
func can_turn() -> bool:
	return can_act() and not hitbox_manager.is_attacking() and is_on_floor()


func is_in_stun() -> bool:
	var state := state_machine.current_state
	if state is FighterHitstunState:
		return true
	return state is FighterBlockState and (state as FighterBlockState).is_in_blockstun()


func is_blocking() -> bool:
	return state_machine.current_state is FighterBlockState


func is_crouching() -> bool:
	var state := state_machine.current_state
	if state is FighterCrouchState:
		return true
	return state is FighterBlockState and (state as FighterBlockState).crouch_block


## Regra de guarda: overhead so defende em pe, baixo so defende abaixado.
func can_block(guard: AttackData.Guard) -> bool:
	if guard == AttackData.Guard.UNBLOCKABLE or not is_blocking():
		return false
	match guard:
		AttackData.Guard.HIGH:
			return not is_crouching()
		AttackData.Guard.LOW:
			return is_crouching()
	return true


func _enter_ko() -> void:
	state_machine.transition_to(&"KO")


func _enter_hitstun(hit: HitData) -> void:
	hitbox_manager.stop_attack()
	var state := state_machine.get_state(&"Hitstun") as FighterHitstunState
	if state == null:
		return
	state.start_hitstun(hit.stun_frames)
	state_machine.transition_to(&"Hitstun")


func _enter_blockstun(hit: HitData) -> void:
	hitbox_manager.stop_attack()
	var state := state_machine.get_state(&"Block") as FighterBlockState
	if state == null:
		return
	state.start_blockstun(hit.stun_frames, is_crouching())
	state_machine.transition_to(&"Block")
