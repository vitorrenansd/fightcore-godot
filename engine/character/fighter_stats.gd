class_name FighterStats
extends Resource

@export var max_health: int = 10000
@export var max_meter: int = 10000

@export_group("Movement")
@export var walk_speed: float = 150.0
@export var dash_speed: float = 400.0
@export var jump_velocity: float = -650.0
@export var gravity: float = 1800.0

@export_group("Combat")
@export var weight: float = 1.0
@export var defense_multiplier: float = 1.0
