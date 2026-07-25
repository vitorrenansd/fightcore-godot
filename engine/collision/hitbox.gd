class_name Hitbox
extends Resource

## Attack volume. Pure immutable data: never becomes a scene node.
##
## The offset is authored in "facing right" space and mirrored at runtime from
## the fighter's facing, never by flipping node scale.
## Hitboxes sharing a hit_group count as a single blow, which describes wide
## attacks without hitting the same target twice; multi-hits use separate
## groups so they can connect again.

@export var shape: Shape2D
## Offset from the fighter origin, in facing-right space.
@export var offset: Vector2 = Vector2.ZERO
## First active frame, counted from the start of the attack.
@export var start_frame: int = 0
## Last active frame, inclusive.
@export var end_frame: int = 0
## Multi-hit moves use different groups so they can connect again.
@export var hit_group: int = 0


func is_active_on_frame(frame: int) -> bool:
	return shape != null and frame >= start_frame and frame <= end_frame


## Query transform, already mirrored to the side the fighter is facing.
func get_query_transform(origin: Vector2, facing_right: bool) -> Transform2D:
	var mirrored := offset
	if not facing_right:
		mirrored.x = -mirrored.x
	return Transform2D(0.0, origin + mirrored)
