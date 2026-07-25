class_name Hurtbox
extends Area2D

## Volume vulneravel de um lutador.
##
## E o unico lado do sistema que vive no servidor de fisica: fica registrada na
## camada do proprio time para ser encontrada pelas consultas do CollisionSolver.
## monitoring fica desligado de proposito, nenhum acerto e resolvido por sinal.
##
## As formas sao filhas CollisionShape2D authoradas na cena. A posicao do no e
## capturada no _ready e espelhada por codigo quando o lutador troca de lado,
## entao cada Hurtbox deve ficar no centro da sua propria caixa.

enum Height {
	HIGH, ## Cabeca e tronco alto, alvo de anti-aereo e overhead.
	MID, ## Corpo padrao.
	LOW, ## Pernas, alvo natural de golpes baixos.
}

@export var height: Height = Height.MID
## Desliga a box sem tirar ela da cena (frames de invencibilidade, reversals).
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
