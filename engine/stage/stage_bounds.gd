class_name StageBounds
extends Node

## The two walls the fight is currently between, and how much they have left.
##
## This node answers where the edges are and holds the damage the walls have
## taken. It never touches a fighter: moving anyone through a broken wall is the
## match's business, so it reports the break and `BattleManager` acts on it.
##
## Only the current section's walls exist. Walking into the next section is not
## a thing a fighter can do — the only way across is to break through — so the
## other sections need no state until the fight is in them.

signal wall_damaged(side: int, health: int)
## The wall on `side` came down and the fight moved from `from` into `to`.
signal wall_broken(side: int, from_section: int, to_section: int)
signal section_changed(section: int)

enum Side {
	LEFT,
	RIGHT,
}

const SIDES: int = 2
## How close a fighter has to be to a wall to count as standing against it.
## A tolerance and not a test for equality: the pushbox solver leaves them a
## fraction of a unit short of the clamp.
const CONTACT_SLACK: float = 1.0

@export var data: StageData

var current_section: int = 0
## Health of the current section's walls, indexed by `Side`.
var wall_health := PackedInt32Array([0, 0])
## Frames since each wall last took damage, indexed by `Side`.
var quiet_frames := PackedInt32Array([0, 0])


func _ready() -> void:
	reset()


## Regen. A wall that is being hit never gets here, because every hit resets
## the count.
func _physics_process(_delta: float) -> void:
	for side in SIDES:
		if wall_health[side] >= data.wall_health:
			continue
		quiet_frames[side] += 1
		if quiet_frames[side] < data.wall_regen_delay:
			continue
		wall_health[side] = mini(wall_health[side] + data.wall_regen_per_frame, data.wall_health)
		wall_damaged.emit(side, wall_health[side])


## Back to the starting section with both walls full, for a new round.
##
## Safe to call before `_ready`, and `BattleManager` does: spawn columns are
## read from the section, so whoever spawns the fighters needs the section to be
## settled first, whatever order the two nodes happen to be readied in.
func reset() -> void:
	if data == null:
		push_error("StageBounds: no StageData, falling back to a default stage")
		data = StageData.new()
	current_section = data.get_start_section()
	refill()
	section_changed.emit(current_section)


func refill() -> void:
	for side in SIDES:
		wall_health[side] = data.wall_health
		quiet_frames[side] = 0


## Wears a wall down, and returns whether that broke it.
func damage_wall(side: int, amount: int) -> bool:
	if amount <= 0:
		return false
	quiet_frames[side] = 0
	wall_health[side] = maxi(wall_health[side] - amount, 0)
	wall_damaged.emit(side, wall_health[side])
	if wall_health[side] > 0:
		return false
	_break_wall(side)
	return true


func get_wall_health(side: int) -> int:
	return wall_health[side]


func get_left() -> float:
	return data.get_section_left(current_section)


func get_right() -> float:
	return data.get_section_right(current_section)


func get_center() -> float:
	return data.get_section_center(current_section)


## Keeps a fighter of half width `half` inside the two walls.
func clamp_x(x: float, half: float) -> float:
	var low := get_left() + half
	var high := get_right() - half
	if low > high:
		return get_center()
	return clampf(x, low, high)


## Room left before the wall on that side, for a fighter of half width `half`.
## This is what a pushbox solve has to respect: a fighter with none of it left
## cannot give ground, so the push has to go somewhere else.
func get_room(x: float, half: float, direction: float) -> float:
	if direction < 0.0:
		return maxf((x - half) - get_left(), 0.0)
	return maxf(get_right() - (x + half), 0.0)


func is_against_wall(x: float, half: float, side: int) -> bool:
	var direction := side_direction(side)
	return get_room(x, half, direction) <= CONTACT_SLACK


## Edge a fighter entering the current section from `direction` comes in
## through. Moving right means coming in at the left edge.
func get_entry_x(direction: float) -> float:
	return get_left() if direction > 0.0 else get_right()


## -1 for the left wall, +1 for the right one. The direction you travel when
## that wall gives way.
static func side_direction(side: int) -> float:
	return -1.0 if side == Side.LEFT else 1.0


static func side_name(side: int) -> String:
	return "left" if side == Side.LEFT else "right"


## Finds the bounds anywhere under `node`. One walk, done at startup by both
## the match and the camera: the bounds live inside the stage scene, which is a
## sibling of neither's parent, so the parent-then-siblings lookup used
## elsewhere in the engine is one level too shallow for them.
static func find_in(node: Node) -> StageBounds:
	if node == null:
		return null
	for child in node.get_children():
		if child is StageBounds:
			return child
		var found := find_in(child)
		if found != null:
			return found
	return null


## Wall a fighter at `x` is standing against, or -1 for neither.
func get_contact_side(x: float, half: float) -> int:
	for side in SIDES:
		if is_against_wall(x, half, side):
			return side
	return -1


func _break_wall(side: int) -> void:
	var from := current_section
	current_section = data.get_neighbour(current_section, int(side_direction(side)))
	# The new section's walls are its own, and they are whole. A wall that
	# stayed broken would take the corner out of the stage one break at a time.
	refill()
	wall_broken.emit(side, from, current_section)
	section_changed.emit(current_section)
