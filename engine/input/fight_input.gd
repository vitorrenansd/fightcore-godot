class_name FightInput
extends RefCounted

## Vocabulario compartilhado do input: botoes, direcoes em notacao numerica e
## limpeza de SOCD. Todo o resto do sistema fala nesses termos.
##
## Direcao usa a notacao numerica do teclado numerico, que e como frame data de
## jogo de luta e escrita no mundo todo:
##
##     7 8 9      cima-tras   cima   cima-frente
##     4 5 6      tras        neutro frente
##     1 2 3      baixo-tras  baixo  baixo-frente
##
## O que a engine guarda e sempre a direcao **absoluta** (4 e esquerda da tela).
## A conversao para frente/tras acontece na hora da leitura, com o facing, para
## um input gravado continuar valendo depois de trocar de lado.

enum Buttons {
	P = 1 << 0, ## Soco
	K = 1 << 1, ## Chute
	S = 1 << 2, ## Slash
	HS = 1 << 3, ## Heavy slash
	D = 1 << 4, ## Dust: overhead sozinho, agarrao com direcao
	SYSTEM_1 = 1 << 5, ## Reservado (burst, roman cancel, macro)
	SYSTEM_2 = 1 << 6,
	SYSTEM_3 = 1 << 7,
}

## Resolucao de direcoes opostas simultaneas, o problema classico de controle
## leverless (hitbox), onde da para segurar esquerda e direita ao mesmo tempo.
enum SOCD {
	NEUTRAL, ## Opostos se cancelam. Padrao de torneio.
	LAST_WINS, ## Vale a direcao apertada por ultimo.
}

const NEUTRAL: int = 5

const BUTTON_NAMES: Dictionary = {
	Buttons.P: &"P",
	Buttons.K: &"K",
	Buttons.S: &"S",
	Buttons.HS: &"HS",
	Buttons.D: &"D",
	Buttons.SYSTEM_1: &"SYSTEM_1",
	Buttons.SYSTEM_2: &"SYSTEM_2",
	Buttons.SYSTEM_3: &"SYSTEM_3",
}

## Botoes de ataque, na ordem de forca. SYSTEM_* fica de fora de proposito.
const ATTACK_BUTTONS: Array[int] = [Buttons.P, Buttons.K, Buttons.S, Buttons.HS, Buttons.D]

const _MIRRORED: Dictionary = {1: 3, 2: 2, 3: 1, 4: 6, 5: 5, 6: 4, 7: 9, 8: 8, 9: 7}


## Monta a direcao numerica a partir dos eixos, com -1 = esquerda/baixo.
static func direction_from_axis(horizontal: int, vertical: int) -> int:
	return 5 + vertical * 3 + horizontal


## Componente horizontal da direcao: -1 esquerda, 1 direita.
static func horizontal(direction: int) -> int:
	return (direction - 1) % 3 - 1


## Componente vertical da direcao: -1 baixo, 1 cima.
static func vertical(direction: int) -> int:
	return (direction - 1) / 3 - 1


## Espelha a direcao para quem encara a esquerda: 6 vira 4, 3 vira 1.
static func mirror(direction: int) -> int:
	return _MIRRORED.get(direction, NEUTRAL)


## Direcao no espaco do lutador: 6 e sempre "para frente".
static func to_relative(direction: int, facing_right: bool) -> int:
	return direction if facing_right else mirror(direction)


static func is_down(direction: int) -> bool:
	return direction <= 3


static func is_up(direction: int) -> bool:
	return direction >= 7


## So vale como tras o que aponta para tras: 4, 1 e 7.
static func is_back(relative_direction: int) -> bool:
	return relative_direction in [1, 4, 7]


static func is_forward(relative_direction: int) -> bool:
	return relative_direction in [3, 6, 9]


## Diagonais podem ser puladas por jogador humano; cardeais nao.
static func is_diagonal(direction: int) -> bool:
	return direction in [1, 3, 7, 9]


## Resolve um eixo com os dois lados apertados ao mesmo tempo.
## `previous` e o valor resolvido no frame anterior, usado pelo modo LAST_WINS.
static func clean_socd(
	negative: bool,
	positive: bool,
	negative_now: bool,
	positive_now: bool,
	previous: int,
	mode: SOCD
) -> int:
	if not negative and not positive:
		return 0
	if negative != positive:
		return 1 if positive else -1
	if mode == SOCD.NEUTRAL:
		return 0
	if positive_now:
		return 1
	if negative_now:
		return -1
	return previous
