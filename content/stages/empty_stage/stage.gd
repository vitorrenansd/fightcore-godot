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
## A wall at full health and a wall about to go. The bar drains between them, so
## the corner tells you how much it has left without a number.
const WALL_FULL_COLOR := Color(0.55, 0.55, 0.6, 0.75)
const WALL_EMPTY_COLOR := Color(0.85, 0.3, 0.3, 0.75)
## Walls of a section nobody is fighting in.
const WALL_IDLE_COLOR := Color(0.16, 0.16, 0.18, 1.0)

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
@export var wall_width: float = 14.0
@export var label_size: int = 48
## How far above the floor the section number sits. Low enough to read as part
## of the ground the fight is on, high enough to clear a standing fighter.
@export var label_height: float = 130.0


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
	_draw_wall(data, StageBounds.Side.LEFT)
	_draw_wall(data, StageBounds.Side.RIGHT)


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
	var x := bounds.get_left() if side == StageBounds.Side.LEFT else bounds.get_right()
	var fraction := float(bounds.get_wall_health(side)) / maxf(data.wall_health, 1.0)
	_draw_wall_bar(x, WALL_EMPTY_COLOR.lerp(WALL_FULL_COLOR, fraction))


func _draw_wall_bar(x: float, color: Color) -> void:
	draw_rect(
		Rect2(x - wall_width * 0.5, floor_top - wall_height, wall_width, wall_height), color
	)
