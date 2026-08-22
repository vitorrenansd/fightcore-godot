class_name CommandData
extends Resource

## Binds an input to a move. This is what turns "236 + S" into an AttackData.
##
## Motions are written in numpad notation, always in fighter space: 6 always
## means "forward", whichever side the fighter is on. Mirroring happens when
## the history is read.
##
##   quarter circle forward: [2, 3, 6]
##   quarter circle back:    [2, 1, 4]
##   dragon punch:           [6, 2, 3]
##   no motion (normal):     []

enum Stance {
	ANY, ## Works standing or crouching.
	STAND, ## Standing only.
	CROUCH, ## Crouching only.
	AIR, ## Airborne only.
}

@export var command_id: StringName
## Move that comes out when the command matches.
@export var attack: AttackData

@export_group("Input")
## Direction sequence, first to last. Empty for a plain normal.
@export var motion: Array[int] = []
## Trigger button. A bitmask and not an enum on purpose: two-button commands
## (throw macro, burst) need to set more than one.
@export_flags("P", "K", "S", "HS", "D", "SYSTEM_1", "SYSTEM_2", "SYSTEM_3")
var button: int = FightInput.Buttons.P
## Direction that must be held together with the button (0 = any).
@export var hold_direction: int = 0
@export var stance: Stance = Stance.ANY

@export_group("Leniency")
## Frame window to finish the whole motion before the button press.
@export var motion_window: int = 20
## Without this a skipped diagonal breaks the motion, and humans skip diagonals.
@export var allow_skipped_diagonals: bool = true

@export_group("Priority")
## Higher wins when two commands match on the same frame.
@export var priority: int = 0


## A command with a motion always beats one without, or 236S would come out as S.
## A held direction counts for the same reason, one rung lower: without it 6D and
## 5D would tie and the throw would come out as a dust, or the other way around,
## decided by nothing but the order of the list.
func get_effective_priority() -> int:
	return priority + motion.size() * 10 + (5 if hold_direction > 0 else 0)


func has_motion() -> bool:
	return not motion.is_empty()
