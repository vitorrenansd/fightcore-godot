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

const FRAMES_PER_SECOND: int = 60

var duration_frames: int = 0
var remaining_frames: int = 0
var running: bool = false


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
