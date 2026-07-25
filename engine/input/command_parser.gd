class_name CommandParser
extends RefCounted

## Matches a fighter's CommandData against the input history.
##
## Recognition walks **backwards in time** from the frame the button went down:
## find the press inside the buffer window, then the last direction of the
## motion, then the one before it, all the way to the first. The genre uses
## this method because it does not care when the motion started, only that it
## was completed in time.
##
## Leniency: a skipped diagonal does not break the motion (almost nobody hits
## the 3 in a 236). A skipped cardinal does.

## Default buffer window. The genre works between 5 and 10 frames: less than
## that punishes legitimate links, more of it throws out moves nobody asked for.
const DEFAULT_BUFFER_FRAMES: int = 8

var buffer_frames: int = DEFAULT_BUFFER_FRAMES


## Best command available this frame, or null.
## `commands` does not need to be sorted: effective priority decides.
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
	# A press already spent by an earlier command does not fire again.
	if history.get_frame() - press_offset <= consumed_until_frame:
		return false
	if command.hold_direction > 0:
		if history.get_direction(press_offset, facing_right) != command.hold_direction:
			return false
	if not command.has_motion():
		return true
	return _matches_motion(command, history, facing_right, press_offset)


## Walks the motion back to front, starting from the button press.
func _matches_motion(
	command: CommandData, history: InputHistory, facing_right: bool, press_offset: int
) -> bool:
	var search_from := press_offset
	var remaining := command.motion_window
	for index in range(command.motion.size() - 1, -1, -1):
		var step: int = command.motion[index]
		var found := history.find_direction(step, search_from, remaining, facing_right)
		if found < 0:
			# A diagonal in the middle of a motion may be missing; a cardinal
			# may not.
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
