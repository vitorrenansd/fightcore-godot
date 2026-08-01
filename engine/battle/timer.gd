class_name RoundTimer
extends RefCounted

## Round clock counted in frames, not seconds.
##
## Named RoundTimer and not Timer because Timer is a native Godot class and the
## name would shadow it.
##
## It counts frames because the whole simulation is frame locked: a clock made
## of real seconds would drift away from the fight and, worse, would make a
## replay or a rollback land on a different countdown.

## The rate the whole engine is written for. Every frame count in the project —
## startup, hitstun, knockdown, this clock — means a sixtieth of a second, so
## the game has to actually run at this rate for any of that data to be true.
##
## It is asserted from here rather than pinned in `project.godot` because Godot
## drops a project setting whose value equals the engine default, and 60 *is*
## the default: the line does not survive the editor saving the project. A
## constant cannot be deleted by a tool that does not know it matters.
const FRAMES_PER_SECOND: int = 60

var duration_frames: int = 0
var remaining_frames: int = 0
var running: bool = false


## True when the project runs at the rate the frame data is written for.
##
## A wrong rate breaks everything quietly: the fight still plays, but every
## startup, every hitstun and every combo route is off by the ratio, and the
## clock counts a second that is not one. Nothing crashes, so it would be found
## by someone wondering why a punish stopped working.
static func verify_tick_rate() -> bool:
	if Engine.physics_ticks_per_second == FRAMES_PER_SECOND:
		return true
	push_error(
		"Physics tick rate is %d, but the engine's frame data assumes %d. " % [
			Engine.physics_ticks_per_second, FRAMES_PER_SECOND,
		]
		+ "Set physics/common/physics_ticks_per_second back to %d." % FRAMES_PER_SECOND
	)
	return false


func start(seconds: int) -> void:
	duration_frames = maxi(seconds, 0) * FRAMES_PER_SECOND
	remaining_frames = duration_frames
	running = duration_frames > 0


func stop() -> void:
	running = false


func resume() -> void:
	running = remaining_frames > 0


## Consumes one frame. True only on the frame the clock runs out.
func tick() -> bool:
	if not running:
		return false
	remaining_frames -= 1
	if remaining_frames > 0:
		return false
	remaining_frames = 0
	running = false
	return true


func is_expired() -> bool:
	return remaining_frames <= 0


## Rounded up, so a full clock reads its starting number until a frame is spent.
func get_seconds_left() -> int:
	return ceili(float(remaining_frames) / FRAMES_PER_SECOND)


func get_ratio() -> float:
	return float(remaining_frames) / duration_frames if duration_frames > 0 else 0.0
