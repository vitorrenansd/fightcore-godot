class_name FighterWalkState
extends FighterState

## Andar para tras tambem e a guarda: quem segura tras defende ao ser atingido,
## como manda a gramatica do genero 2D. Quem decide isso e Fighter.is_blocking.

var direction: float = 0.0


func physics_update(delta: float) -> void:
	super(delta)
	if handle_grounded_input():
		return
	if fighter.input != null:
		direction = FightInput.horizontal(fighter.input.get_direction())
	fighter.walk(direction)
