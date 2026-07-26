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

@export_group("Juggle")
## Extra gravity per point of juggle already on the fighter. This is what ends
## an air combo: every hit makes the victim fall faster, so the same route stops
## reaching. Damage scaling alone never closes a loop, it only makes it cheap.
@export_range(0.0, 1.0, 0.01) var juggle_gravity_per_hit: float = 0.12
## Ceiling for the juggle multiplier, so a long combo does not turn the victim
## into a stone that lands before the next hit can ever come out.
@export_range(1.0, 5.0, 0.1) var max_juggle_gravity: float = 2.2

@export_group("Knockdown")
## Frames lying on the floor after landing from a knockdown, before getting up.
## This is the okizeme window: the attacker's time to set up.
@export var knockdown_frames: int = 24
## Frames the rise takes. Invulnerable throughout, actionable at the end.
@export var wakeup_frames: int = 16

@export_group("Pushbox")
## Width of the volume that keeps fighters from standing inside each other.
## Bigger characters take more space and lose ground faster in the corner.
@export var pushbox_width: float = 46.0

@export_group("Combat")
@export var weight: float = 1.0
@export var defense_multiplier: float = 1.0
