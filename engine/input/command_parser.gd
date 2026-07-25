class_name CommandParser
extends RefCounted

## Casa os CommandData de um lutador contra o historico de input.
##
## O reconhecimento anda **para tras no tempo**, partindo do frame em que o
## botao desceu: acha o botao dentro da janela de buffer, depois procura a
## ultima direcao do motion, depois a anterior, ate a primeira. E o metodo usado
## no genero porque nao depende de quando o motion comecou, so de ele ter sido
## completado a tempo.
##
## Leniencia: diagonal pulada nao invalida o motion (jogador humano quase nunca
## acerta o 3 de um 236). Cardeal pulada invalida.

## Janela de buffer padrao. O genero trabalha entre 5 e 10 frames: menos que
## isso pune link legitimo, mais que isso solta golpe que o jogador nao quis.
const DEFAULT_BUFFER_FRAMES: int = 8

var buffer_frames: int = DEFAULT_BUFFER_FRAMES


## Melhor comando disponivel no frame atual, ou null.
## `commands` nao precisa vir ordenado: a prioridade efetiva decide.
func parse(
	commands: Array[CommandData],
	history: InputHistory,
	facing_right: bool,
	stance: CommandData.Stance,
	consumed_until_frame: int = -1
) -> CommandData:
	var best: CommandData = null
	var best_priority: int = -1
	for command in commands:
		if command == null or command.attack == null:
			continue
		if not _matches_stance(command, stance):
			continue
		var priority := command.get_effective_priority()
		if best != null and priority <= best_priority:
			continue
		if matches(command, history, facing_right, consumed_until_frame):
			best = command
			best_priority = priority
	return best


func matches(
	command: CommandData,
	history: InputHistory,
	facing_right: bool,
	consumed_until_frame: int = -1
) -> bool:
	var press_offset := history.find_press(command.button, buffer_frames)
	if press_offset < 0:
		return false
	# Aperto ja gasto por um comando anterior nao dispara de novo.
	if history.get_frame() - press_offset <= consumed_until_frame:
		return false
	if command.hold_direction > 0:
		if history.get_direction(press_offset, facing_right) != command.hold_direction:
			return false
	if not command.has_motion():
		return true
	return _matches_motion(command, history, facing_right, press_offset)


## Percorre o motion de tras para frente a partir do aperto do botao.
func _matches_motion(
	command: CommandData, history: InputHistory, facing_right: bool, press_offset: int
) -> bool:
	var search_from := press_offset
	var remaining := command.motion_window
	for index in range(command.motion.size() - 1, -1, -1):
		var step: int = command.motion[index]
		var found := history.find_direction(step, search_from, remaining, facing_right)
		if found < 0:
			# Diagonal no meio do motion pode faltar; cardeal nao.
			if command.allow_skipped_diagonals and FightInput.is_diagonal(step) and index > 0:
				continue
			return false
		remaining -= found - search_from
		if remaining <= 0:
			return false
		search_from = found
	return true


func _matches_stance(command: CommandData, stance: CommandData.Stance) -> bool:
	if command.stance == CommandData.Stance.ANY:
		return stance != CommandData.Stance.AIR
	return command.stance == stance
