extends SceneTree

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var p1: Fighter
var p2: Fighter
var solver: CollisionSolver
var frames: int = 0
var landed: Array[HitData] = []
var ok: bool = true


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)

	p1 = scene.instantiate()
	p1.team = 0
	root.add_child(p1)
	p1.position = Vector2(0, 0)

	p2 = scene.instantiate()
	p2.team = 1
	root.add_child(p2)
	p2.position = Vector2(60, 0)

	solver = CollisionSolver.new()
	root.add_child(solver)
	solver.register_fighter(p1)
	solver.register_fighter(p2)
	solver.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))


func _make_attack(guard: AttackData.Guard, damage: int, chip: int) -> AttackData:
	var box := Hitbox.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = Vector2(60, 60)
	box.shape = box_shape
	box.offset = Vector2(60, 0)
	box.start_frame = 4
	box.end_frame = 6

	var attack := AttackData.new()
	attack.startup_frames = 4
	attack.active_frames = 3
	attack.recovery_frames = 8
	attack.damage = damage
	attack.chip_damage = chip
	attack.guard = guard
	attack.hitstun = 16
	attack.blockstun = 12
	attack.hitstop = 6
	attack.hitboxes = [box]
	return attack


## O knockback ainda nao decai no chao (nao existe atrito), entao entre as fases
## o espacamento e refeito na mao.
func _reset_spacing() -> void:
	p1.position = Vector2(0, 0)
	p1.velocity = Vector2.ZERO
	p2.position = Vector2(60, 0)
	p2.velocity = Vector2.ZERO


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FALHA: %s" % message)


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			# Os @onready dos lutadores so resolvem depois que o tree roda.
			p1.opponent = p2
			p2.opponent = p1
			p1.set_facing(true)
			p2.set_facing(false)
			print("p1 hurtboxes=%d  p2 hurtboxes=%d  layer p2=%d  mascara p1=%d" % [
				p1.hitbox_manager.get_hurtboxes().size(),
				p2.hitbox_manager.get_hurtboxes().size(),
				p2.hitbox_manager.get_hurtboxes()[0].collision_layer,
				CollisionLayers.opponent_hurtbox_mask(p1.team),
			])
			var attack := _make_attack(AttackData.Guard.MID, 400, 0)
			print("\n== 1. acerto limpo (MID, sem guarda) ==")
			print("  frame data: total=%d vantagem_hit=%+d vantagem_block=%+d seguro=%s" % [
				attack.get_total_frames(),
				attack.get_advantage_on_hit(),
				attack.get_advantage_on_block(),
				attack.is_safe_on_block(),
			])
			p1.hitbox_manager.start_attack(attack)
		8:
			check(p1.hitstop_frames > 0, "atacante tambem congela no hitstop")
			check(p2.hitstop_frames > 0, "alvo congela no hitstop")
		12:
			check(landed.size() == 1, "1 acerto esperado, hit_group deve impedir reacerto")
			var hit: HitData = landed[0]
			print("  dano=%d stun=%d hitstop=%d knockback=%s blocked=%s scaling=%.2f" % [
				hit.damage, hit.stun_frames, hit.hitstop, hit.knockback, hit.blocked, hit.damage_scaling,
			])
			check(hit.damage == 400, "dano 400")
			check(hit.knockback.x > 0.0, "knockback para a direita")
			check(p2.health == 9600, "vida 9600, veio %d" % p2.health)
			check(p2.state_machine.current_state.name == &"Hitstun", "p2 em Hitstun")
			check(p2.combo_hits == 1, "combo_hits 1, veio %d" % p2.combo_hits)
		34:
			print("  fim do hitstun: estado=%s combo_hits=%d atacando=%s" % [
				p2.state_machine.current_state.name, p2.combo_hits, p1.hitbox_manager.is_attacking(),
			])
			check(p2.state_machine.current_state.name == &"Idle", "p2 voltou para Idle")
			check(p2.combo_hits == 0, "combo zera ao sair do hitstun")
			check(not p1.hitbox_manager.is_attacking(), "ataque terminou sozinho")
		36:
			print("\n== 2. mesmo golpe defendido (MID, guarda em pe) ==")
			landed.clear()
			_reset_spacing()
			p2.state_machine.transition_to(&"Block")
			p1.hitbox_manager.start_attack(_make_attack(AttackData.Guard.MID, 400, 40))
		47:
			check(landed.size() == 1, "1 acerto esperado")
			var hit: HitData = landed[0]
			print("  blocked=%s dano=%d stun=%d vida=%d estado=%s" % [
				hit.blocked, hit.damage, hit.stun_frames, p2.health, p2.state_machine.current_state.name,
			])
			check(hit.blocked, "golpe MID deveria ser defendido")
			check(hit.damage == 40, "so chip damage")
			check(hit.stun_frames == 12, "blockstun 12")
			check(p2.health == 9560, "vida 9560, veio %d" % p2.health)
			check(p2.combo_hits == 0, "defesa nao conta combo")
		70:
			print("\n== 3. golpe baixo contra guarda em pe ==")
			landed.clear()
			_reset_spacing()
			p2.state_machine.transition_to(&"Block")
			p1.hitbox_manager.start_attack(_make_attack(AttackData.Guard.LOW, 300, 30))
		81:
			check(landed.size() == 1, "1 acerto esperado")
			var hit: HitData = landed[0]
			print("  blocked=%s dano=%d vida=%d estado=%s" % [
				hit.blocked, hit.damage, p2.health, p2.state_machine.current_state.name,
			])
			check(not hit.blocked, "guarda em pe nao defende golpe baixo")
			check(p2.health == 9260, "vida 9260, veio %d" % p2.health)
			check(p2.state_machine.current_state.name == &"Hitstun", "p2 em Hitstun")
		82:
			print("\nRESULTADO: %s" % ("OK" if ok else "FALHOU"))
			quit(0 if ok else 1)
			return true
	return false
