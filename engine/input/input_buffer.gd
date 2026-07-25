class_name InputBuffer
extends Node

## A fighter's input component: samples the device once per physics frame,
## records it in the history and answers the questions states ask.
##
## A fighter without this node simply never receives a command — that is how
## the training dummy stands there taking hits.
##
## The buffer exists because demanding the exact frame is unfair: the player
## presses a few frames before they are allowed to act and the move still has
## to come out. That is also why sampling continues during hitstop, which is
## exactly when the player is setting up the rest of the combo.

signal command_accepted(command: CommandData)

## Buffer window in frames. The genre works between 5 and 10.
@export var buffer_frames: int = CommandParser.DEFAULT_BUFFER_FRAMES
@export var socd_mode: FightInput.SOCD = FightInput.SOCD.NEUTRAL

var player_index: int = 0:
	set = set_player_index

var enabled: bool = true
var device: InputDevice
var history: InputHistory
var parser: CommandParser

## Frame up to which presses have already been spent by some command.
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


## Samples the current frame. Called by the Fighter every frame, frozen or not.
func poll() -> void:
	if history == null:
		return
	if enabled:
		history.push(device.read_direction(), device.read_buttons())
	else:
		history.push(FightInput.NEUTRAL, 0)


## Best command available right now, or null. Consumes nothing.
func get_command(commands: Array[CommandData], facing_right: bool, stance: CommandData.Stance) -> CommandData:
	if history == null or commands.is_empty():
		return null
	return parser.parse(commands, history, facing_right, stance, _consumed_frame)


## Spends the current buffer so the same press cannot fire twice.
func consume() -> void:
	if history != null:
		_consumed_frame = history.get_frame()


## Confirms a command came out: spends the buffer and notifies listeners.
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
