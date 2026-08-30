class_name FightCamera
extends Camera2D

## Sits still in the middle of the section being fought in, and cuts to the next
## one when a wall breaks.
##
## **The zoom never changes.** A section is exactly one screen wide and the walls
## keep both fighters inside it, so there is nothing for a zoom to react to: the
## pair cannot get further apart than the view already shows. A camera that
## pulled back with distance would be answering a question the walls already
## answered, and it would make the fighters change size for no reason a player
## can act on.
##
## Nothing here follows anyone and nothing runs per frame. The frame is the
## section, the section is the screen, and the only thing that ever moves the
## camera is a break.

## Walls the view is locked to. Found next to the battle when left empty.
@export var bounds: StageBounds
## Fixed zoom. Paired with `StageData.section_width`: at this zoom the view is
## exactly one section wide, so the walls land on the edges of the screen.
## Changing one without the other is what makes the corner stop lining up.
@export var fixed_zoom: float = 0.9
## Where the camera sits relative to the middle of the section, at floor level.
@export var focus_offset: Vector2 = Vector2(0.0, 60.0)


func _ready() -> void:
	if bounds == null:
		bounds = StageBounds.find_in(get_parent())
	if bounds != null:
		bounds.section_changed.connect(_on_section_changed)
	make_current()
	snap()


## Puts the camera on the current section, with no travel. Every move this
## camera makes is a cut: both fighters were placed rather than walked over, and
## easing into it would be a shot of the stage sliding past.
func snap() -> void:
	zoom = Vector2(fixed_zoom, fixed_zoom)
	if bounds != null:
		global_position = Vector2(bounds.get_center() + focus_offset.x, focus_offset.y)
	reset_physics_interpolation()


func get_visible_width() -> float:
	return get_viewport_rect().size.x / maxf(fixed_zoom, 0.01)


func _on_section_changed(_section: int) -> void:
	snap()
