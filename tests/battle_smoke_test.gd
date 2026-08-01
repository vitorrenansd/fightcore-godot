extends SceneTree

## Checks the match built by BattleManager: spawn, teams, facing, the
## CollisionSolver running on its own, and the KO.
##
##   godot --headless --path . --script tests/battle_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var landed: Array[HitData] = []
var deaths: Array[Fighter] = []
var ok: bool = true


func _initialize() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)

	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(0, 0), Vector2(60, 0)]
	battle.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))
	battle.fighter_died.connect(func(fighter: Fighter) -> void: deaths.append(fighter))
	root.add_child(battle)


func _make_attack(damage: int) -> AttackData:
	var box := Hitbox.new()
	var box_shape := RectangleShape2D.new()
	box_shape.size = Vector2(60, 60)
	box.shape = box_shape
	box.offset = Vector2(60, 0)
	box.start_frame = 4
	box.end_frame = 6

	var attack := AttackData.new()
	attack.attack_id = &"5L"
	attack.startup_frames = 4
	attack.active_frames = 3
	attack.recovery_frames = 8
	attack.damage = damage
	attack.hitstun = 16
	attack.hitstop = 6
	attack.hitboxes = [box]
	return attack


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
			print("== 1. match built by BattleManager ==")
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			check(battle.fighters.size() == 2, "2 fighters in the match")
			check(p1 != null and p2 != null, "fighters reachable by team")
			check(battle.solver != null and battle.solver.fighters.size() == 2, "solver has both registered")
			check(p1.opponent == p2 and p2.opponent == p1, "opponents linked")
			check(p1.facing_right and not p2.facing_right, "fighters facing each other")
			print("  p1 team=%d facing_right=%s | p2 team=%d facing_right=%s" % [
				p1.team, p1.facing_right, p2.team, p2.facing_right,
			])
			print("  p1 hurtbox layer=%d | p2 hurtbox layer=%d" % [
				p1.hitbox_manager.get_hurtboxes()[0].collision_layer,
				p2.hitbox_manager.get_hurtboxes()[0].collision_layer,
			])

			print("\n== 2. move through the attack state ==")
			check(p1.perform_attack(_make_attack(400)), "perform_attack accepted")
			check(p1.state_machine.current_state.name == &"Attack", "p1 entered Attack")
		6:
			print("  frame 6: p1 state=%s attack_frame=%d | p2 state=%s health=%d" % [
				p1.state_machine.current_state.name,
				p1.hitbox_manager.attack_frame,
				p2.state_machine.current_state.name,
				p2.health,
			])
			check(landed.size() == 1, "BattleManager solver resolved the hit")
			check(p2.health == 9600, "health 9600, got %d" % p2.health)
			check(p2.state_machine.current_state.name == &"Hitstun", "p2 in Hitstun")
			check(not p1.can_act(), "attacker locked during the move")
		30:
			print("  move over: p1 state=%s | p2 state=%s" % [
				p1.state_machine.current_state.name, p2.state_machine.current_state.name,
			])
			check(p1.state_machine.current_state.name == &"Idle", "p1 returned to Idle on its own")
			check(p1.can_act(), "p1 free again")

			print("\n== 3. facing flipped by position ==")
			p1.position = Vector2(200, 0)
			p2.position = Vector2(0, 0)
		32:
			print("  p1 facing_right=%s | p2 facing_right=%s" % [p1.facing_right, p2.facing_right])
			check(not p1.facing_right, "p1 turned left")
			check(p2.facing_right, "p2 turned right")
		34:
			print("\n== 4. KO ==")
			_reset_spacing()
			p2.health = 300
			landed.clear()
		36:
			# Facing only settles a frame after repositioning, and stops
			# changing once the move has started.
			check(p1.facing_right, "p1 faces the opponent again before the move")
			check(p1.perform_attack(_make_attack(400)), "finishing move accepted")
		47:
			print("  p2 health=%d state=%s deaths=%d" % [
				p2.health, p2.state_machine.current_state.name, deaths.size(),
			])
			check(p2.health == 0, "health reached zero")
			check(p2.state_machine.current_state.name == &"KO", "p2 in KO")
			check(deaths.size() == 1 and deaths[0] == p2, "BattleManager reported the death")
			check(not p2.can_be_hit(), "a KOd fighter leaves solver queries")
			check(not p2.can_act(), "a KOd fighter cannot act")
		48:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
