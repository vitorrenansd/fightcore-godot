class_name FighterJumpState
extends FighterState

## O pulo e comprometido: a direcao e lida uma vez, na saida do chao, e nao muda
## mais no ar. E o que faz espacamento no ar significar alguma coisa.


func enter() -> void:
	super()
	fighter.jump()
	if fighter.input != null:
		var horizontal := FightInput.horizontal(fighter.input.get_direction())
		fighter.velocity.x = horizontal * fighter.stats.walk_speed


func physics_update(delta: float) -> void:
	super(delta)
	fighter.try_command()
	# state_frame > 1 evita voltar para Idle no mesmo frame da saida do chao,
	# antes da velocidade vertical tirar o lutador do piso.
	if state_frame > 1 and fighter.is_on_floor():
		transitioned.emit(&"Idle")
