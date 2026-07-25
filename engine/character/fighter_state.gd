class_name FighterState
extends State

@onready var fighter: Fighter = owner as Fighter


## Trata o input de um estado no chao: comando primeiro, movimento depois.
## Verdadeiro quando trocou de estado, e ai o chamador deve parar por aqui.
##
## Golpe vem antes de andar de proposito: apertar 6P nao pode virar so um passo
## para frente.
func handle_grounded_input() -> bool:
	if fighter.try_command():
		return true
	var target := get_grounded_state()
	if target == name:
		return false
	transitioned.emit(target)
	return true


## Estado que a direcao segurada pede agora.
func get_grounded_state() -> StringName:
	if fighter.input == null:
		return &"Idle"
	var direction := fighter.input.get_direction()
	if FightInput.is_up(direction):
		return &"Jump"
	if FightInput.is_down(direction):
		return &"Crouch"
	if FightInput.horizontal(direction) != 0:
		return &"Walk"
	return &"Idle"
