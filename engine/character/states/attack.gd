class_name FighterAttackState
extends FighterState

## Runs an AttackData. Counting frames and activating hitboxes is the
## HitboxManager's job; this state only waits for the attack to finish.

var attack: AttackData


## Sets the move before entering the state. If the fighter is already
## attacking, restarts right away: that is how a cancel becomes the next move
## without passing through neutral, since transition_to ignores a transition
## into the current state.
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
