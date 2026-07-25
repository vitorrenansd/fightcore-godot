class_name InputHistory
extends RefCounted

## Circular input history, one record per physics frame.
##
## Stores direction and button bitmask in fixed arrays, allocating nothing per
## frame. Offset 0 is always the current frame, 1 the previous one, and so on —
## that is how the command parser reads motions walking backwards in time.
##
## The stored direction is always absolute; mirroring for the facing happens on
## read, so input recorded before a side switch still counts.

const DEFAULT_SIZE: int = 90

var size: int

var _directions: PackedInt32Array
var _buttons: PackedInt32Array
var _head: int = 0
## Total frames recorded so far. Doubles as a timestamp for buffer consumption.
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


## Current frame number since reading started.
func get_frame() -> int:
	return _frame


func get_direction(offset: int = 0, facing_right: bool = true) -> int:
	return FightInput.to_relative(_directions[_index(offset)], facing_right)


func get_buttons(offset: int = 0) -> int:
	return _buttons[_index(offset)]


func is_held(button_mask: int, offset: int = 0) -> bool:
	return _buttons[_index(offset)] & button_mask == button_mask


## True only on the frame the button went down.
func is_pressed(button_mask: int, offset: int = 0) -> bool:
	var current := _buttons[_index(offset)]
	var previous := _buttons[_index(offset + 1)]
	return current & button_mask == button_mask and previous & button_mask != button_mask


## Offset of the frame the button went down within the window, or -1.
## Searches newest to oldest: the latest press wins.
func find_press(button_mask: int, window: int) -> int:
	for offset in mini(window, size - 1):
		if is_pressed(button_mask, offset):
			return offset
	return -1


## Offset where a direction appears, searching from `from` backwards in time.
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
