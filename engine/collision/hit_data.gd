class_name HitData
extends Resource

## Resultado ja resolvido de um acerto, entregue ao alvo pelo CollisionSolver.
##
## Diferente de AttackData (dado authorado, compartilhado entre lutadores), um
## HitData e criado por acerto e ja carrega dano escalonado, knockback no espaco
## do mundo e a reacao escolhida. Quem recebe nao precisa reinterpretar nada.

var attacker: Fighter
var victim: Fighter
var attack: AttackData

## Ponto aproximado do impacto, util para hit sparks.
var position: Vector2 = Vector2.ZERO
var blocked: bool = false
var counter_hit: bool = false

var damage: int = 0
var stun_frames: int = 0
var hitstop: int = 0
var knockback: Vector2 = Vector2.ZERO
var launcher: bool = false

## Quantos golpes o alvo ja tinha levado neste combo antes deste acerto.
var combo_index: int = 0
var damage_scaling: float = 1.0


## Monta o resultado final a partir do dado authorado do golpe.
static func build(
	p_attack: AttackData,
	p_attacker: Fighter,
	p_victim: Fighter,
	p_position: Vector2,
	p_blocked: bool,
	p_counter_hit: bool
) -> HitData:
	var hit := HitData.new()
	hit.attack = p_attack
	hit.attacker = p_attacker
	hit.victim = p_victim
	hit.position = p_position
	hit.blocked = p_blocked
	hit.counter_hit = p_counter_hit and not p_blocked
	hit.combo_index = p_victim.combo_hits
	hit.damage_scaling = p_attack.get_damage_scaling(hit.combo_index)
	hit.launcher = p_attack.launcher and not p_blocked

	var defense := p_victim.stats.defense_multiplier if p_victim.stats != null else 1.0
	if hit.blocked:
		hit.damage = int(round(p_attack.chip_damage * defense))
		hit.stun_frames = p_attack.blockstun
	else:
		var raw := p_attack.damage * hit.damage_scaling * defense
		if hit.counter_hit:
			raw *= p_attack.counter_hit_damage_multiplier
		hit.damage = maxi(int(round(raw)), 1)
		hit.stun_frames = p_attack.hitstun
		if hit.counter_hit:
			hit.stun_frames += p_attack.counter_hit_bonus_hitstun

	hit.hitstop = p_attack.hitstop
	hit.knockback = _build_knockback(p_attack, p_attacker, p_victim, hit.blocked)
	return hit


## Knockback ja orientado pelo facing do atacante e aliviado pelo peso do alvo.
static func _build_knockback(
	p_attack: AttackData, p_attacker: Fighter, p_victim: Fighter, p_blocked: bool
) -> Vector2:
	var source := p_attack.block_pushback if p_blocked else p_attack.knockback
	var direction := 1.0 if p_attacker.facing_right else -1.0
	var weight := p_victim.stats.weight if p_victim.stats != null else 1.0
	return Vector2(source.x * direction, source.y) / maxf(weight, 0.1)
