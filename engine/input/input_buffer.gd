class_name InputBuffer
extends Node

## Componente de input de um lutador: amostra o dispositivo uma vez por frame de
## fisica, guarda no historico e responde as perguntas que os estados fazem.
##
## Um lutador sem este no simplesmente nao recebe comando — e assim que o
## training dummy fica parado apanhando.
##
## O buffer existe porque exigir o frame exato e injusto: o jogador aperta o
## botao alguns frames antes de poder agir e o golpe tem que sair mesmo assim.
## Por isso a amostragem continua durante o hitstop, que e justamente quando o
## jogador esta montando a continuacao do combo.

signal command_accepted(command: CommandData)

## Janela de buffer em frames. O genero trabalha entre 5 e 10.
@export var buffer_frames: int = CommandParser.DEFAULT_BUFFER_FRAMES
@export var socd_mode: FightInput.SOCD = FightInput.SOCD.NEUTRAL

var player_index: int = 0:
	set = set_player_index

var enabled: bool = true
var device: InputDevice
var history: InputHistory
var parser: CommandParser

## Frame ate o qual os apertos ja foram gastos por algum comando.
var _consumed_frame: int = -1


func _ready() -> void:
	history = InputHistory.new()
	parser = CommandParser.new()
	parser.buffer_frames = buffer_frames
	device = InputDevice.new(player_index)
	device.socd_mode = socd_mode


func set_player_index(index: int) -> void:
	player_index = index
	if device != null:
		device.set_player_index(index)


## Amostra o frame atual. Chamado pelo Fighter, sempre — inclusive congelado.
func poll() -> void:
	if history == null:
		return
	if enabled:
		history.push(device.read_direction(), device.read_buttons())
	else:
		history.push(FightInput.NEUTRAL, 0)


## Melhor comando disponivel agora, ou null. Nao consome nada.
func get_command(commands: Array[CommandData], facing_right: bool, stance: CommandData.Stance) -> CommandData:
	if history == null or commands.is_empty():
		return null
	return parser.parse(commands, history, facing_right, stance, _consumed_frame)


## Gasta o buffer atual, para o mesmo aperto nao disparar duas vezes.
func consume() -> void:
	if history != null:
		_consumed_frame = history.get_frame()


## Confirma que o comando saiu: gasta o buffer e avisa quem estiver ouvindo.
func accept(command: CommandData) -> void:
	consume()
	command_accepted.emit(command)


func get_direction(facing_right: bool = true) -> int:
	return history.get_direction(0, facing_right) if history != null else FightInput.NEUTRAL


func is_holding_back(facing_right: bool) -> bool:
	return FightInput.is_back(get_direction(facing_right))


func is_holding_forward(facing_right: bool) -> bool:
	return FightInput.is_forward(get_direction(facing_right))


func is_holding_down() -> bool:
	return FightInput.is_down(get_direction())


func is_holding_up() -> bool:
	return FightInput.is_up(get_direction())


func is_held(button_mask: int) -> bool:
	return history != null and history.is_held(button_mask)
