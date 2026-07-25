class_name CollisionLayers
extends RefCounted

## Mapa de camadas de fisica do FightCore.
##
## Hurtboxes sao Area2D registradas no espaco de fisica em uma camada por time.
## Hitboxes NAO sao corpos fisicos: elas consultam o espaco direto via
## PhysicsDirectSpaceState2D.intersect_shape (ver CollisionSolver), entao a
## unica coisa que precisa existir no servidor de fisica sao as hurtboxes.

const WORLD: int = 1 << 0
const PUSHBOX: int = 1 << 1
const HURTBOX_TEAM_0: int = 1 << 2
const HURTBOX_TEAM_1: int = 1 << 3

const TEAM_COUNT: int = 2


## Camada onde as hurtboxes do time informado entram.
static func hurtbox_layer(team: int) -> int:
	return HURTBOX_TEAM_0 << (team % TEAM_COUNT)


## Mascara que um atacante do time informado usa para achar alvos.
static func opponent_hurtbox_mask(team: int) -> int:
	return hurtbox_layer(team + 1)
