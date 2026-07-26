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
	# Polling here is what makes cancels exist: the command comes out mid-move
	# instead of waiting for recovery. Fighter.can_start_attack decides whether
	# the cancel is legal.
	if fighter.try_command():
		return
	# Landing cuts an air move short, the usual landing recovery of the genre.
	if attack != null and attack.ends_on_landing and state_frame > 1 and fighter.is_on_floor():
		transitioned.emit(&"Idle")
		return
	if not fighter.hitbox_manager.is_attacking():
		transitioned.emit(&"Jump" if not fighter.is_on_floor() else &"Idle")


func _begin() -> void:
	state_frame = 0
	# A grounded move plants the fighter; an air move keeps the jump arc.
	if attack != null and not attack.ends_on_landing:
		fighter.velocity.x = 0.0
	fighter.hitbox_manager.start_attack(attack)
