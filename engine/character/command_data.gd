class_name CommandData
extends Resource

## Liga um input a um golpe. E o que transforma "236 + P" em um AttackData.
##
## O motion e escrito em notacao numerica, sempre no espaco do lutador: 6 e
## sempre "para frente", independente do lado em que ele esta. O espelhamento
## acontece na leitura do historico.
##
##   meia lua para frente: [2, 3, 6]
##   meia lua para tras:   [2, 1, 4]
##   dragon punch:         [6, 2, 3]
##   sem motion (normal):  []

enum Stance {
	ANY, ## Serve em pe ou agachado.
	STAND, ## So em pe.
	CROUCH, ## So agachado.
	AIR, ## So no ar.
}

@export var command_id: StringName
## Golpe que sai quando o comando acerta.
@export var attack: AttackData

@export_group("Input")
## Sequencia de direcoes, da primeira para a ultima. Vazio para golpe normal.
@export var motion: Array[int] = []
## Botao que dispara. Bitmask e nao enum de proposito: comando de dois botoes
## (macro de agarrao, burst) precisa marcar mais de um.
@export_flags("P", "K", "S", "HS", "D", "SYSTEM_1", "SYSTEM_2", "SYSTEM_3")
var button: int = FightInput.Buttons.P
## Direcao que precisa estar segurada junto com o botao (0 = tanto faz).
@export var hold_direction: int = 0
@export var stance: Stance = Stance.ANY

@export_group("Leniencia")
## Frames de janela para completar o motion inteiro antes do botao.
@export var motion_window: int = 20
## Sem isto, diagonal pulada invalida o motion. Jogador humano pula diagonal.
@export var allow_skipped_diagonals: bool = true

@export_group("Prioridade")
## Maior vence quando dois comandos batem no mesmo frame.
@export var priority: int = 0


## Comando com motion sempre ganha de comando sem motion, senao 236P sai como P.
func get_effective_priority() -> int:
	return priority + motion.size() * 10


func has_motion() -> bool:
	return not motion.is_empty()
