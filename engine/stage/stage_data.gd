class_name StageData
extends Resource

## Shape of a stage: how many screens it has, how wide one is, and what the
## walls between them cost to break.
##
## A stage is a **ring** of sections. Breaking the wall on one side moves the
## fight into the neighbour on that side, and the outer wall of the last section
## leads back to the first, so no section is a dead end and the count can be two
## or eleven without any of them being special.
##
## The wall does not stay broken. It comes back full in the new section, which
## is what keeps the corner meaning the same thing on the tenth break as on the
## first — a ring whose walls stayed down would end up as one open field.
##
## Where the two of them land after a break is not written here. It is the same
## distance a round starts at, which `BattleManager` already knows, and a second
## copy of it would be a number to keep in step for no gain.
##
## Authored data only, shared between rounds. The damage a wall has taken is
## runtime state and lives in `StageBounds`.

## Screens the stage is made of. Two is the smallest ring that still has two
## different places to be.
@export_range(2, 16) var section_count: int = 3
## Width of one screen in world units, which is also the distance between the
## two walls. Matched to what the camera frames at its widest zoom, so a section
## is exactly as big as the view that has to hold it.
@export var section_width: float = 1280.0
## Section the round starts in. `-1` picks the middle one, the only choice that
## leaves the same number of walls on either side.
@export var start_section: int = -1

@export_group("Walls")
## Damage a wall takes before it breaks, against fighters who have 10000. It is
## a little over one full corner combo, so breaking one asks for a second trip
## rather than falling out of the first.
@export var wall_health: int = 3000
## Frames without damage before a wall starts coming back. Short enough that a
## dropped combo gives the wall back, long enough that the gaps inside a
## blockstring do not.
@export var wall_regen_delay: int = 40
## Health returned per frame once the regen starts. At this rate a wall goes
## from empty to full in a second, which is the "quickly" part: leaving someone
## alone in the corner undoes the work of putting them there.
@export var wall_regen_per_frame: int = 50
## Damage the breaking wall deals to whoever went through it.
@export var wall_break_damage: int = 800


## Centre of a section in world units. Sections are laid out left to right with
## the middle of the stage at x 0, so a three screen stage puts its starting
## section exactly where a single screen stage would have been.
func get_section_center(index: int) -> float:
	return (index - (section_count - 1) * 0.5) * section_width


func get_section_left(index: int) -> float:
	return get_section_center(index) - section_width * 0.5


func get_section_right(index: int) -> float:
	return get_section_center(index) + section_width * 0.5


## Number shown on the section, counting from 1 the way a player would.
func get_section_label(index: int) -> int:
	return index + 1


func get_start_section() -> int:
	if start_section >= 0:
		return wrapi(start_section, 0, section_count)
	return section_count / 2


## Section reached by leaving this one in `direction` (-1 left, +1 right).
## Wraps, which is the whole ring: there is no last section to be stuck in.
func get_neighbour(index: int, direction: int) -> int:
	return wrapi(index + direction, 0, section_count)


## Total width of every section together, for whatever has to cover the stage.
func get_total_width() -> float:
	return section_width * section_count
