class_name AttackData
extends Resource

## Frame data e propriedades de acerto de um golpe.
##
## Tudo que define o comportamento de um ataque vive aqui como .tres, nunca como
## constante em script. Vantagem em hit e block sao derivadas do frame data em
## vez de authoradas, para nao existir dado duplicado que desincronize.

enum Guard {
	MID, ## Defende em pe ou abaixado.
	HIGH, ## Overhead: so defende em pe.
	LOW, ## Baixo: so defende abaixado.
	UNBLOCKABLE, ## Nao ha defesa.
}

@export var attack_id: StringName
@export var display_name: String

@export_group("Frame Data")
## Frames antes da primeira hitbox ficar ativa.
@export var startup_frames: int = 5
## Frames com hitbox ativa.
@export var active_frames: int = 3
## Frames de recuperacao depois das hitboxes sumirem.
@export var recovery_frames: int = 12

@export_group("Boxes")
@export var hitboxes: Array[Hitbox] = []

@export_group("Dano")
@export var damage: int = 400
## Dano ao acertar a guarda do oponente.
@export var chip_damage: int = 0
## Reducao de dano por hit ja acumulado no combo (10% e o padrao do genero).
@export_range(0.0, 1.0, 0.01) var scaling_per_hit: float = 0.1
## Piso do escalonamento, impede combos longos zerarem o dano.
@export_range(0.0, 1.0, 0.01) var min_damage_scaling: float = 0.1
@export var counter_hit_damage_multiplier: float = 1.2
@export var counter_hit_bonus_hitstun: int = 4

@export_group("Reacao")
@export var guard: Guard = Guard.MID
## Frames que o oponente fica preso ao levar o golpe.
@export var hitstun: int = 16
## Frames que o oponente fica preso ao defender o golpe.
@export var blockstun: int = 12
## Frames de congelamento dos dois lados no impacto.
@export var hitstop: int = 8
## Empurrao no acerto. X e sempre "para longe do atacante".
@export var knockback: Vector2 = Vector2(220.0, 0.0)
## Empurrao na defesa.
@export var block_pushback: Vector2 = Vector2(120.0, 0.0)
## Lanca o oponente para o alto, permitindo juggle.
@export var launcher: bool = false


func get_total_frames() -> int:
	return startup_frames + active_frames + recovery_frames


## Ultimo frame do ataque, contando a partir de 0.
func get_last_frame() -> int:
	return get_total_frames() - 1


func is_active_on_frame(frame: int) -> bool:
	for hitbox in hitboxes:
		if hitbox != null and hitbox.is_active_on_frame(frame):
			return true
	return false


## Frames que sobram para o atacante depois de acertar no primeiro frame ativo.
func get_recovery_after_hit() -> int:
	return maxi(active_frames - 1, 0) + recovery_frames


func get_advantage_on_hit() -> int:
	return hitstun - get_recovery_after_hit()


func get_advantage_on_block() -> int:
	return blockstun - get_recovery_after_hit()


func is_safe_on_block() -> bool:
	return get_advantage_on_block() >= 0


## Escalonamento aplicado quando o alvo ja levou combo_index golpes no combo.
func get_damage_scaling(combo_index: int) -> float:
	return maxf(1.0 - scaling_per_hit * combo_index, min_damage_scaling)
