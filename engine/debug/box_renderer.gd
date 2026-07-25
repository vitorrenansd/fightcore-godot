class_name DebugBoxRenderer
extends Node2D

## Draws hurtboxes and active hitboxes on top of the match.
##
## Without this, tuning frame data is pure guesswork: it is the only way to see
## that a hitbox came out on the right frame, in the right place, facing the
## right way.

const HURTBOX_COLOR := Color(0.25, 0.8, 0.35, 0.22)
const HITBOX_COLOR := Color(0.95, 0.25, 0.25, 0.35)
const PIVOT_COLOR := Color(1.0, 1.0, 1.0, 0.5)
const PIVOT_RADIUS := 3.0

@export var battle: BattleManager
@export var enabled: bool = true:
	set = set_enabled


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func set_enabled(value: bool) -> void:
	enabled = value
	queue_redraw()


func _draw() -> void:
	if not enabled or battle == null:
		return
	for fighter in battle.fighters:
		_draw_hurtboxes(fighter)
		_draw_hitboxes(fighter)
		draw_circle(to_local(fighter.global_position), PIVOT_RADIUS, PIVOT_COLOR)


func _draw_hurtboxes(fighter: Fighter) -> void:
	for hurtbox in fighter.hitbox_manager.get_hurtboxes():
		if not hurtbox.is_active():
			continue
		for child in hurtbox.get_children():
			if child is CollisionShape2D and child.shape != null:
				_draw_shape(child.shape, to_local(child.global_position), HURTBOX_COLOR)


func _draw_hitboxes(fighter: Fighter) -> void:
	for hitbox in fighter.hitbox_manager.get_active_hitboxes():
		var box_transform := hitbox.get_query_transform(fighter.global_position, fighter.facing_right)
		_draw_shape(hitbox.shape, to_local(box_transform.origin), HITBOX_COLOR)


func _draw_shape(shape: Shape2D, local_position: Vector2, color: Color) -> void:
	draw_set_transform(local_position)
	shape.draw(get_canvas_item(), color)
	draw_set_transform(Vector2.ZERO)
