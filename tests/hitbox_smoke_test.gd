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
	# Blocking is now holding back, so the test needs the InputMap.
	InputBindings.create_default().apply()

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


## Ground knockback does not decay yet (there is no friction), so spacing is
## restored by hand between phases.
func _reset_spacing() -> void:
	p1.position = Vector2(0, 0)
	p1.velocity = Vector2.ZERO
	p2.position = Vector2(60, 0)
	p2.velocity = Vector2.ZERO


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			# Fighter @onready vars only resolve once the tree is running.
			p1.opponent = p2
			p2.opponent = p1
			p1.set_facing(true)
			p2.set_facing(false)
			p2.input.player_index = 1
			print("p1 hurtboxes=%d  p2 hurtboxes=%d  p2 layer=%d  p1 mask=%d" % [
				p1.hitbox_manager.get_hurtboxes().size(),
				p2.hitbox_manager.get_hurtboxes().size(),
				p2.hitbox_manager.get_hurtboxes()[0].collision_layer,
				CollisionLayers.opponent_hurtbox_mask(p1.team),
			])
			var attack := _make_attack(AttackData.Guard.MID, 400, 0)
			print("\n== 1. clean hit (MID, no guard) ==")
			print("  frame data: total=%d adv_hit=%+d adv_block=%+d safe=%s" % [
				attack.get_total_frames(),
				attack.get_advantage_on_hit(),
				attack.get_advantage_on_block(),
				attack.is_safe_on_block(),
			])
			p1.hitbox_manager.start_attack(attack)
		8:
			check(p1.hitstop_frames > 0, "attacker freezes on hitstop too")
			check(p2.hitstop_frames > 0, "target freezes on hitstop")
		12:
			check(landed.size() == 1, "exactly 1 hit, hit_group must prevent re-hits")
			var hit: HitData = landed[0]
			print("  damage=%d stun=%d hitstop=%d knockback=%s blocked=%s scaling=%.2f" % [
				hit.damage, hit.stun_frames, hit.hitstop, hit.knockback, hit.blocked, hit.damage_scaling,
			])
			check(hit.damage == 400, "400 damage")
			check(hit.knockback.x > 0.0, "knockback pushes right")
			check(p2.health == 9600, "health 9600, got %d" % p2.health)
			check(p2.state_machine.current_state.name == &"Hitstun", "p2 in Hitstun")
			check(p2.combo_hits == 1, "combo_hits 1, got %d" % p2.combo_hits)
		34:
			print("  hitstun over: state=%s combo_hits=%d attacking=%s" % [
				p2.state_machine.current_state.name, p2.combo_hits, p1.hitbox_manager.is_attacking(),
			])
			check(p2.state_machine.current_state.name == &"Idle", "p2 returned to Idle")
			check(p2.combo_hits == 0, "combo resets on leaving hitstun")
			check(not p1.hitbox_manager.is_attacking(), "attack ended on its own")
		36:
			print("\n== 2. same move blocked (MID, standing guard) ==")
			landed.clear()
			_reset_spacing()
			# p2 faces left, so its "back" is screen right.
			Input.action_press(&"p2_right")
			p1.hitbox_manager.start_attack(_make_attack(AttackData.Guard.MID, 400, 40))
		47:
			check(landed.size() == 1, "exactly 1 hit")
			var hit: HitData = landed[0]
			print("  blocked=%s damage=%d stun=%d health=%d state=%s" % [
				hit.blocked, hit.damage, hit.stun_frames, p2.health, p2.state_machine.current_state.name,
			])
			check(hit.blocked, "MID move should be blocked")
			check(hit.damage == 40, "chip damage only")
			check(hit.stun_frames == 12, "blockstun 12")
			check(p2.health == 9560, "health 9560, got %d" % p2.health)
			check(p2.combo_hits == 0, "blocking does not count as combo")
		70:
			print("\n== 3. low move against standing guard ==")
			landed.clear()
			_reset_spacing()
			# Still holding back, but standing: a high guard does not stop a low.
			p1.hitbox_manager.start_attack(_make_attack(AttackData.Guard.LOW, 300, 30))
		81:
			check(landed.size() == 1, "exactly 1 hit")
			var hit: HitData = landed[0]
			print("  blocked=%s damage=%d health=%d state=%s" % [
				hit.blocked, hit.damage, p2.health, p2.state_machine.current_state.name,
			])
			check(not hit.blocked, "standing guard does not block a low")
			check(p2.health == 9260, "health 9260, got %d" % p2.health)
			check(p2.state_machine.current_state.name == &"Hitstun", "p2 in Hitstun")
		82:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
