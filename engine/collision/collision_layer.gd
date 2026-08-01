class_name CollisionLayers
extends RefCounted

## Physics layer map for FightCore.
##
## Hurtboxes are Area2D volumes registered in the physics space, one layer per
## team. Hitboxes are NOT physics bodies: they query the space directly through
## PhysicsDirectSpaceState2D.intersect_shape (see CollisionSolver), so hurtboxes
## are the only thing that has to exist in the physics server.

const WORLD: int = 1 << 0
const PUSHBOX: int = 1 << 1
const HURTBOX_TEAM_0: int = 1 << 2
const HURTBOX_TEAM_1: int = 1 << 3

const TEAM_COUNT: int = 2


## Layer the given team's hurtboxes live on.
static func hurtbox_layer(team: int) -> int:
	return HURTBOX_TEAM_0 << (team % TEAM_COUNT)


## Mask an attacker of the given team uses to find targets.
static func opponent_hurtbox_mask(team: int) -> int:
	return hurtbox_layer(team + 1)
