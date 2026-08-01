class_name Hurtbox
extends Area2D

## Vulnerable volume of a fighter.
##
## The only side of the system that lives in the physics server: registered on
## its own team's layer so CollisionSolver queries can find it. Monitoring is
## off on purpose, no hit is ever resolved through a signal.
##
## Shapes are CollisionShape2D children authored in the scene. The node
## position is captured on _ready and mirrored in code when the fighter turns
## around, so every Hurtbox must sit at the center of its own box.

enum Height {
	HIGH, ## Head and upper torso, target for anti-airs and overheads.
	MID, ## Default body.
	LOW, ## Legs, the natural target for low attacks.
}

@export var height: Height = Height.MID
## Turns the box off without removing it (invincibility frames, reversals).
@export var invulnerable: bool = false

var fighter: Fighter
var enabled: bool = true

var _base_position: Vector2


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	_base_position = position
	_refresh_layer()


func setup(owner_fighter: Fighter) -> void:
	fighter = owner_fighter
	_refresh_layer()


func set_enabled(value: bool) -> void:
	enabled = value
	_refresh_layer()


func set_invulnerable(value: bool) -> void:
	invulnerable = value
	_refresh_layer()


func set_facing(facing_right: bool) -> void:
	position = Vector2(_base_position.x if facing_right else -_base_position.x, _base_position.y)


func is_active() -> bool:
	return enabled and not invulnerable


func _refresh_layer() -> void:
	collision_layer = CollisionLayers.hurtbox_layer(fighter.team) if fighter != null and is_active() else 0
