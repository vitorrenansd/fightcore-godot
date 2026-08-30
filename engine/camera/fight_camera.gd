class_name FightCamera
extends Camera2D

## Frames both fighters: centred between them, zoomed out as they spread, and
## never showing past the walls of the section they are in.
##
## Only the horizontal axis follows. A camera that chased height would drop the
## floor out of frame on every jump, and the floor is the thing a player reads
## spacing against.
##
## Runs in `_physics_process` with the rest of the match. It changes nothing
## about the simulation — the camera is looked at, never asked — but sharing the
## tick keeps it from lagging a frame behind the fighters it is framing.

@export var battle: BattleManager
## Walls the view is kept inside. Found next to the battle when left empty.
@export var bounds: StageBounds
## Height the camera sits at, above the fighters' feet.
@export var focus_offset: Vector2 = Vector2(0.0, 60.0)
## Space kept outside the pair on each side, so neither is framed against the
## edge of the screen with nothing in front of them.
@export var margin: float = 200.0
## Widest the view goes. One section is sized to be exactly this much, so a
## fully spread pair fills the screen with the walls at its corners.
@export var min_zoom: float = 0.9
## Closest the view goes, for a pair standing on top of each other. Past this
## the two of them stop reading as small figures on a stage.
@export var max_zoom: float = 1.5
## Fraction of the distance left that is covered each frame. Low enough that the
## view does not snap around on a knockback, high enough to keep up with a dash.
@export_range(0.0, 1.0) var follow: float = 0.18


func _ready() -> void:
	if battle == null:
		battle = _find_battle()
	if bounds == null and battle != null:
		bounds = battle.stage_bounds
	if bounds != null:
		bounds.section_changed.connect(_on_section_changed)
	make_current()
	snap()


func _physics_process(_delta: float) -> void:
	var wanted_zoom := _wanted_zoom()
	zoom = zoom.lerp(Vector2(wanted_zoom, wanted_zoom), follow)
	# Clamped against the zoom the camera actually has and not the one it is
	# heading for, or it would show past the wall for the frames in between.
	var wanted := _clamp_to_section(_wanted_center())
	global_position.x = lerpf(global_position.x, wanted, follow)
	global_position.y = _focus_y()


## Puts the camera where it belongs this instant, with no travel. Used on a
## section change and at the start of a round: both are teleports, and easing
## into them would be a shot of the stage sliding past.
func snap() -> void:
	var wanted_zoom := _wanted_zoom()
	zoom = Vector2(wanted_zoom, wanted_zoom)
	global_position = Vector2(_clamp_to_section(_wanted_center()), _focus_y())
	reset_physics_interpolation()


func get_visible_width() -> float:
	var viewport := get_viewport_rect().size.x
	return viewport / maxf(zoom.x, 0.01)


func _wanted_center() -> float:
	var pair := _living_fighters()
	if pair.is_empty():
		return bounds.get_center() if bounds != null else global_position.x
	var total := 0.0
	for fighter in pair:
		total += fighter.global_position.x
	return total / pair.size() + focus_offset.x


func _focus_y() -> float:
	var pair := _living_fighters()
	if pair.is_empty():
		return global_position.y
	# The lower of the two, so the ground stays put while one of them jumps.
	var lowest := -INF
	for fighter in pair:
		lowest = maxf(lowest, fighter.global_position.y)
	return lowest + focus_offset.y


func _wanted_zoom() -> float:
	var pair := _living_fighters()
	if pair.size() < 2:
		return maxf(min_zoom, 0.01)
	var spread := absf(pair[0].global_position.x - pair[1].global_position.x)
	var needed := spread + margin * 2.0
	if needed <= 0.0:
		return max_zoom
	var viewport := get_viewport_rect().size.x
	return clampf(viewport / needed, min_zoom, max_zoom)


## Keeps the view inside the current section. A section narrower than the view
## is centred instead of clamped, which is the only sane answer when there is
## nothing to slide.
func _clamp_to_section(x: float) -> float:
	if bounds == null:
		return x
	var half := get_visible_width() * 0.5
	var left := bounds.get_left()
	var right := bounds.get_right()
	if right - left <= half * 2.0:
		return (left + right) * 0.5
	return clampf(x, left + half, right - half)


func _living_fighters() -> Array[Fighter]:
	var pair: Array[Fighter] = []
	if battle == null:
		return pair
	for fighter in battle.fighters:
		if fighter != null and is_instance_valid(fighter):
			pair.append(fighter)
	return pair


## Same lookup the debug renderer uses: parent first, then siblings.
func _find_battle() -> BattleManager:
	var parent := get_parent()
	if parent is BattleManager:
		return parent
	if parent == null:
		return null
	for sibling in parent.get_children():
		if sibling is BattleManager:
			return sibling
	return null


func _on_section_changed(_section: int) -> void:
	snap()
