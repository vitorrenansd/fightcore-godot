class_name FighterAttackState
extends FighterState

## Executa um AttackData. Quem conta os frames e ativa as hitboxes e o
## HitboxManager; este estado so espera o ataque terminar para voltar ao neutro.

var attack: AttackData


## Define o golpe antes de entrar no estado. Se o lutador ja estiver atacando,
## reinicia na hora: e assim que um cancel vira o golpe seguinte sem passar pelo
## neutro, ja que transition_to ignora transicao para o estado atual.
func setup(new_attack: AttackData) -> void:
	attack = new_attack
	if fighter.state_machine.current_state == self:
		_begin()


func enter() -> void:
	super()
	_begin()


func exit() -> void:
	super()
	fighter.hitbox_manager.stop_attack()
	attack = null


func physics_update(delta: float) -> void:
	super(delta)
	if not fighter.hitbox_manager.is_attacking():
		transitioned.emit(&"Idle")


func _begin() -> void:
	state_frame = 0
	fighter.velocity.x = 0.0
	fighter.hitbox_manager.start_attack(attack)
