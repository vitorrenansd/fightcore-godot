extends Node2D

## Placeholder stage: builds its sections from `StageData` at runtime.
##
## There is no art yet, so a section is a rectangle with its number in the
## middle and a bar at each edge for the wall. The two walls of the section
## being fought in are drawn solid and drain as they take damage; the rest are
## drawn faint, because they are scenery until the fight reaches them.
##
## Built in code and not authored as nodes because the section count is a number
## in the data: a stage with five screens must not need five copies of anything.
## Once there is art a section becomes a scene, and this script is what it
## replaces.

const BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const FLOOR_COLOR := Color(0.16565639, 0.16565642, 0.16565639, 1.0)
## Boundary between two sections, drawn behind everything so it reads as a seam
## and not as an object in the fight.
const SEAM_COLOR := Color(0.09, 0.09, 0.09, 1.0)
const LABEL_COLOR := Color(0.32, 0.32, 0.32, 1.0)
## A wall at full health and a wall about to go. The slab shifts between them, so
## the corner tells you how much it has left without a number.
const WALL_FULL_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const WALL_EMPTY_COLOR := Color(0.9, 0.28, 0.28, 1.0)
## Walls of a section nobody is fighting in.
const WALL_IDLE_COLOR := Color(0.16, 0.16, 0.18, 1.0)
## Empty part of a wall meter, and the outline that separates it from the
## backdrop. Both dark: the meter has to read as a gauge on the stage and not as
## another slab standing in the fight.
const METER_TRACK_COLOR := Color(0.1, 0.1, 0.11, 1.0)
const METER_BORDER_COLOR := Color(0.0, 0.0, 0.0, 1.0)

@onready var bounds: StageBounds = $Bounds
@onready var floor_body: StaticBody2D = $Floor
@onready var floor_shape: CollisionShape2D = $Floor/CollisionShape2D

@export_group("Layout")
## Y of the floor surface. Everything else is measured from it, so moving the
## ground moves the whole stage with it.
@export var floor_top: float = 200.0
@export var floor_thickness: float = 80.0
## How far up the backdrop goes.
@export var ceiling: float = -800.0

@export_group("Placeholder art")
@export var wall_height: float = 420.0
@export var wall_width: float = 22.0
@export var label_size: int = 48
## How far above the floor the section number sits. Low enough to read as part
## of the ground the fight is on, high enough to clear a standing fighter.
@export var label_height: float = 130.0

@export_group("Wall meter")
## Length of the bar beside each wall of the section being fought in.
@export var meter_width: float = 200.0
@export var meter_height: float = 14.0
## Gap between the wall and the end of its bar.
@export var meter_inset: float = 12.0
## How far below the floor surface the bar sits. On the ground rather than up
## the wall: down there nothing in the fight ever covers it, and a fighter
## standing in the corner is the one moment the wall's health matters most.
@export var meter_drop: float = 18.0
@export var meter_border: float = 2.0


func _ready() -> void:
	_build_floor()


## Redrawn every frame: the wall bars drain and refill while the fight runs, and
## a placeholder is not worth a dirty flag.
func _process(_delta: float) -> void:
	queue_redraw()


## One body under every section. The fighters find the ground by casting, so the
## only thing that matters here is that it reaches from end to end.
func _build_floor() -> void:
	var data := bounds.data
	var shape := RectangleShape2D.new()
	shape.size = Vector2(data.get_total_width(), floor_thickness)
	floor_shape.shape = shape
	floor_body.position = Vector2(0.0, floor_top + floor_thickness * 0.5)


func _draw() -> void:
	var data := bounds.data
	for index in data.section_count:
		_draw_section(data, index)
	for side in StageBounds.SIDES:
		_draw_wall(data, side)
		_draw_wall_meter(data, side)


func _draw_section(data: StageData, index: int) -> void:
	var left := data.get_section_left(index)
	var width := data.section_width
	draw_rect(Rect2(left, ceiling, width, floor_top - ceiling), BACKGROUND_COLOR)
	draw_rect(Rect2(left, floor_top, width, floor_thickness), FLOOR_COLOR)
	draw_rect(Rect2(left, ceiling, 2.0, floor_top - ceiling), SEAM_COLOR)
	# Every section's walls are drawn, faint, so the shape of the stage is
	# visible from wherever the fight is. The live pair is painted over them.
	_draw_wall_bar(left, WALL_IDLE_COLOR)
	_draw_wall_bar(left + width, WALL_IDLE_COLOR)
	_draw_label(data, index)


func _draw_label(data: StageData, index: int) -> void:
	var font := ThemeDB.fallback_font
	var text := str(data.get_section_label(index))
	draw_string(
		font,
		Vector2(data.get_section_left(index), floor_top - label_height),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		data.section_width,
		label_size,
		LABEL_COLOR
	)


func _draw_wall(data: StageData, side: int) -> void:
	_draw_wall_bar(_wall_x(side), WALL_EMPTY_COLOR.lerp(WALL_FULL_COLOR, _wall_fraction(data, side)))


## A health bar for the wall, laid out like a fighter's: a dark track with the
## remaining health filling it.
##
## The slab already changes colour, which says the wall has been hurt but not how
## much of it is left, and the regen is a thing you have to be able to watch come
## back. A colour you have to remember the last shade of does not show that; a bar
## creeping along does.
##
## It drains toward the middle of the section, so the health that is left is the
## part still hugging the corner it protects.
func _draw_wall_meter(data: StageData, side: int) -> void:
	# Away from the wall is away from the edge it sits on.
	var inward := -StageBounds.side_direction(side)
	var near := _wall_x(side) + inward * meter_inset
	var fraction := _wall_fraction(data, side)
	var filled := meter_width * fraction
	var top := floor_top + meter_drop
	var track_left := near if inward > 0.0 else near - meter_width
	var fill_left := near if inward > 0.0 else near - filled
	draw_rect(
		Rect2(
			track_left - meter_border,
			top - meter_border,
			meter_width + meter_border * 2.0,
			meter_height + meter_border * 2.0
		),
		METER_BORDER_COLOR
	)
	draw_rect(Rect2(track_left, top, meter_width, meter_height), METER_TRACK_COLOR)
	if filled > 0.0:
		draw_rect(
			Rect2(fill_left, top, filled, meter_height),
			WALL_EMPTY_COLOR.lerp(WALL_FULL_COLOR, fraction)
		)


func _wall_x(side: int) -> float:
	return bounds.get_left() if side == StageBounds.Side.LEFT else bounds.get_right()


func _wall_fraction(data: StageData, side: int) -> float:
	return float(bounds.get_wall_health(side)) / maxf(data.wall_health, 1.0)


func _draw_wall_bar(x: float, color: Color) -> void:
	draw_rect(
		Rect2(x - wall_width * 0.5, floor_top - wall_height, wall_width, wall_height), color
	)
