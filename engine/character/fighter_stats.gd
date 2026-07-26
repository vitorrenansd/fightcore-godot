class_name FighterStats
extends Resource

@export var max_health: int = 10000
@export var max_meter: int = 10000

@export_group("Movement")
@export var walk_speed: float = 150.0
@export var dash_speed: float = 400.0
@export var jump_velocity: float = -650.0
@export var gravity: float = 1800.0

@export_group("Air")
## Extra jumps allowed before touching the ground again.
@export var air_jumps: int = 1
## Weaker than the ground jump on purpose, so the second jump is a commitment
## and not a way to hover.
@export var air_jump_velocity: float = -560.0
@export var air_dashes: int = 1
@export var air_dash_speed: float = 420.0
## How long the dash holds its momentum with gravity suspended.
@export var air_dash_frames: int = 18

@export_group("Pushbox")
## Width of the volume that keeps fighters from standing inside each other.
## Bigger characters take more space and lose ground faster in the corner.
@export var pushbox_width: float = 46.0

@export_group("Combat")
@export var weight: float = 1.0
@export var defense_multiplier: float = 1.0
