class_name FighterKOState
extends FighterState

## Lutador nocauteado. Nao sai deste estado sozinho: quem tira dele e o reset de
## round. Mantem o knockback do golpe final e so freia ao encostar no chao.

func enter() -> void:
	super()
	fighter.hitbox_manager.stop_attack()
	fighter.hitbox_manager.set_hurtboxes_enabled(false)


func exit() -> void:
	super()
	fighter.hitbox_manager.set_hurtboxes_enabled(true)


func physics_update(delta: float) -> void:
	super(delta)
	if fighter.is_on_floor():
		fighter.velocity.x = 0.0
