class_name AttackData
extends Resource

## Frame data and hit properties of a move.
##
## Everything that defines an attack lives here as a .tres, never as script
## constants. Advantage on hit and block are derived from the frame data
## instead of authored, so there is no duplicated value that can drift.

enum Guard {
	MID, ## Blocks standing or crouching.
	HIGH, ## Overhead: only blocks standing.
	LOW, ## Low: only blocks crouching.
	UNBLOCKABLE, ## No block at all.
}

## Move class, used by the cancel rules.
enum CancelType {
	NORMAL, ## Plain button attack.
	SPECIAL, ## Motion input move.
	SUPER, ## Meter spender.
}

@export var attack_id: StringName
@export var display_name: String

@export_group("Frame Data")
## Frames before the first hitbox goes active.
@export var startup_frames: int = 5
## Frames with an active hitbox.
@export var active_frames: int = 3
## Recovery frames after the hitboxes are gone.
@export var recovery_frames: int = 12

@export_group("Boxes")
@export var hitboxes: Array[Hitbox] = []

@export_group("Cancels")
@export var cancel_type: CancelType = CancelType.NORMAL
## Move classes this attack may cancel into.
@export_flags("Normal", "Special", "Super") var cancel_into_types: int = 6
## Gatling ladder for normal into normal: only cancels into a higher level.
## Following the button order P=0, K=1, S=2, HS=3, D=4 gives the whole chain
## for free, with no route authored one by one.
@export var cancel_level: int = 0
## Explicit extra routes by attack id, for exceptions to the ladder.
@export var cancel_into: Array[StringName] = []
## Cancelling without touching the opponent. Off by default: whiff cancelling
## erases the risk of throwing out a move, which is what makes neutral matter.
@export var can_whiff_cancel: bool = false
## First frame this move can be cancelled, from the start of the attack.
## -1 means the first active frame, which is the genre default.
@export var cancel_window_start: int = -1

@export_group("Damage")
@export var damage: int = 400
## Damage dealt when the opponent blocks.
@export var chip_damage: int = 0
## Damage cut per hit already in the combo (10% is the genre standard).
@export_range(0.0, 1.0, 0.01) var scaling_per_hit: float = 0.1
## Scaling floor, so long combos cannot drop damage to nothing.
@export_range(0.0, 1.0, 0.01) var min_damage_scaling: float = 0.1
@export var counter_hit_damage_multiplier: float = 1.2
@export var counter_hit_bonus_hitstun: int = 4

@export_group("Reaction")
@export var guard: Guard = Guard.MID
## Frames the opponent is stuck for after being hit.
@export var hitstun: int = 16
## Frames the opponent is stuck for after blocking.
@export var blockstun: int = 12
## Freeze frames applied to both sides on impact.
@export var hitstop: int = 8
## Knockback on hit. X always points away from the attacker.
@export var knockback: Vector2 = Vector2(220.0, 0.0)
## Pushback on block.
@export var block_pushback: Vector2 = Vector2(120.0, 0.0)
## Launches the opponent upwards, allowing juggles.
@export var launcher: bool = false


func get_total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## Last frame of the attack, counting from 0.
func get_last_frame() -> int:
	return get_total_frames() - 1


func is_active_on_frame(frame: int) -> bool:
	for hitbox in hitboxes:
		if hitbox != null and hitbox.is_active_on_frame(frame):
			return true
	return false


## Frames the attacker still owes after connecting on the first active frame.
func get_recovery_after_hit() -> int:
	return maxi(active_frames - 1, 0) + recovery_frames


func get_advantage_on_hit() -> int:
	return hitstun - get_recovery_after_hit()


func get_advantage_on_block() -> int:
	return blockstun - get_recovery_after_hit()


func is_safe_on_block() -> bool:
	return get_advantage_on_block() >= 0


## First frame this move accepts a cancel.
func get_cancel_window_start() -> int:
	return cancel_window_start if cancel_window_start >= 0 else startup_frames


## Whether this move is allowed to cancel into `other`.
##
## An explicit route always wins. Otherwise the target class has to be allowed,
## and normal into normal has to climb the gatling ladder — without that rule a
## move could chain into itself forever.
func can_cancel_into(other: AttackData) -> bool:
	if other == null:
		return false
	if cancel_into.has(other.attack_id):
		return true
	if cancel_into_types & (1 << other.cancel_type) == 0:
		return false
	if other.cancel_type == CancelType.NORMAL:
		return other.cancel_level > cancel_level
	return true


## Scaling applied when the target has already taken combo_index hits.
func get_damage_scaling(combo_index: int) -> float:
	return maxf(1.0 - scaling_per_hit * combo_index, min_damage_scaling)
