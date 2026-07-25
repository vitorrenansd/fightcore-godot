class_name InputHistory
extends RefCounted

## Historico circular de input, um registro por frame de fisica.
##
## Guarda direcao e bitmask de botoes em arrays fixos, sem alocar nada por
## frame. Offset 0 e sempre o frame atual, 1 e o anterior, e assim por diante —
## e assim que o parser de comando lê motion andando para tras no tempo.
##
## A direcao guardada e sempre absoluta; espelhar para o facing acontece na
## leitura, para input gravado antes de trocar de lado continuar valendo.

const DEFAULT_SIZE: int = 90

var size: int

var _directions: PackedInt32Array
var _buttons: PackedInt32Array
var _head: int = 0
## Total de frames ja gravados. Serve de carimbo de tempo para consumo.
var _frame: int = 0


func _init(history_size: int = DEFAULT_SIZE) -> void:
	size = maxi(history_size, 2)
	_directions.resize(size)
	_buttons.resize(size)
	_directions.fill(FightInput.NEUTRAL)
	_buttons.fill(0)


func push(direction: int, buttons: int) -> void:
	_head = (_head + 1) % size
	_directions[_head] = direction
	_buttons[_head] = buttons
	_frame += 1


## Numero do frame atual desde o inicio da leitura.
func get_frame() -> int:
	return _frame


func get_direction(offset: int = 0, facing_right: bool = true) -> int:
	return FightInput.to_relative(_directions[_index(offset)], facing_right)


func get_buttons(offset: int = 0) -> int:
	return _buttons[_index(offset)]


func is_held(button_mask: int, offset: int = 0) -> bool:
	return _buttons[_index(offset)] & button_mask == button_mask


## Verdadeiro so no frame em que o botao desceu.
func is_pressed(button_mask: int, offset: int = 0) -> bool:
	var current := _buttons[_index(offset)]
	var previous := _buttons[_index(offset + 1)]
	return current & button_mask == button_mask and previous & button_mask != button_mask


## Offset do frame em que o botao desceu dentro da janela, ou -1.
## Procura do mais recente para o mais antigo: o ultimo aperto vence.
func find_press(button_mask: int, window: int) -> int:
	for offset in mini(window, size - 1):
		if is_pressed(button_mask, offset):
			return offset
	return -1


## Offset em que a direcao aparece, procurando de `from` para tras no tempo.
func find_direction(direction: int, from: int, window: int, facing_right: bool) -> int:
	for offset in range(from, mini(from + window, size - 1)):
		if get_direction(offset, facing_right) == direction:
			return offset
	return -1


func clear() -> void:
	_directions.fill(FightInput.NEUTRAL)
	_buttons.fill(0)


func _index(offset: int) -> int:
	return (_head - offset % size + size) % size
