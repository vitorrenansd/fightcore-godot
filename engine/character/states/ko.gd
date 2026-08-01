class_name FighterKOState
extends FighterState

## Knocked out fighter. Never leaves this state on its own: only a round reset
## takes it out. Keeps the knockback of the finishing blow and stops on landing.

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
