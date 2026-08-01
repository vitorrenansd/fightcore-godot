class_name FightInput
extends RefCounted

## Shared input vocabulary: buttons, numpad directions and SOCD cleaning.
## The rest of the system speaks in these terms.
##
## Directions use numpad notation, the way fighting game frame data is written
## everywhere:
##
##     7 8 9      up-back    up      up-forward
##     4 5 6      back       neutral forward
##     1 2 3      down-back  down    down-forward
##
## What the engine stores is always the **absolute** direction (4 is screen
## left). Converting to forward/back happens on read, using the facing, so an
## input recorded before a side switch still means what the player intended.

enum Buttons {
	P = 1 << 0, ## Punch
	K = 1 << 1, ## Kick
	S = 1 << 2, ## Slash
	HS = 1 << 3, ## Heavy slash
	D = 1 << 4, ## Dust: overhead alone, throw with a direction
	SYSTEM_1 = 1 << 5, ## Reserved (burst, roman cancel, macro)
	SYSTEM_2 = 1 << 6,
	SYSTEM_3 = 1 << 7,
}

## Resolution for simultaneous opposite directions, the classic problem of
## leverless controllers (hitbox), where left and right can be held together.
enum SOCD {
	NEUTRAL, ## Opposites cancel out. Tournament standard.
	LAST_WINS, ## The most recently pressed direction wins.
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

## Attack buttons, in strength order. SYSTEM_* is left out on purpose.
const ATTACK_BUTTONS: Array[int] = [Buttons.P, Buttons.K, Buttons.S, Buttons.HS, Buttons.D]

const _MIRRORED: Dictionary = {1: 3, 2: 2, 3: 1, 4: 6, 5: 5, 6: 4, 7: 9, 8: 8, 9: 7}


## Builds the numpad direction from axes, where -1 is left/down.
static func direction_from_axis(horizontal: int, vertical: int) -> int:
	return 5 + vertical * 3 + horizontal


## Horizontal component of a direction: -1 left, 1 right.
static func horizontal(direction: int) -> int:
	return (direction - 1) % 3 - 1


## Vertical component of a direction: -1 down, 1 up.
static func vertical(direction: int) -> int:
	return (direction - 1) / 3 - 1


## Mirrors a direction for a fighter facing left: 6 becomes 4, 3 becomes 1.
static func mirror(direction: int) -> int:
	return _MIRRORED.get(direction, NEUTRAL)


## Direction in fighter space: 6 always means "forward".
static func to_relative(direction: int, facing_right: bool) -> int:
	return direction if facing_right else mirror(direction)


static func is_down(direction: int) -> bool:
	return direction <= 3


static func is_up(direction: int) -> bool:
	return direction >= 7


## Only directions actually pointing backwards count: 4, 1 and 7.
static func is_back(relative_direction: int) -> bool:
	return relative_direction in [1, 4, 7]


static func is_forward(relative_direction: int) -> bool:
	return relative_direction in [3, 6, 9]


## Diagonals can be skipped by a human player; cardinals cannot.
static func is_diagonal(direction: int) -> bool:
	return direction in [1, 3, 7, 9]


## Resolves one axis with both sides held at once.
## `previous` is last frame's resolved value, used by LAST_WINS.
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
