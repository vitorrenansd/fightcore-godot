class_name Knockback

## Rules for knockback that outlives the frame it was applied on.
##
## No node and no state: the `Fighter` owns its velocity, this only decides how
## that velocity decays. Kept out of `Fighter` so the rule has one home and can
## be read — and tested — without a scene tree around it.

## Bleeds horizontal speed toward zero at `friction` px/s².
##
## `move_toward` is what makes this safe: it stops exactly at zero instead of
## overshooting into the opposite direction, so a heavy hit never bounces the
## victim back toward the attacker on the frame the slide ends.
static func apply_friction(horizontal: float, friction: float, delta: float) -> float:
	return move_toward(horizontal, 0.0, friction * delta)
