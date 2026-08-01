extends SceneTree

## Checks the air moves: stance picks the air version, the jump arc survives the
## attack, landing cuts it short, and an air attack is an overhead.
##
##   godot --headless --path . --script tests/air_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var accepted: Array[CommandData] = []
var landed: Array[HitData] = []
var ok: bool = true

var _held: Array[StringName] = []
var _air_velocity_x: float = 0.0


func _initialize() -> void:
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	floor_shape.shape = rect
	floor_body.position = Vector2(0, 70)
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(-140, 0), Vector2(140, 0)]
	battle.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))
	root.add_child(battle)


func hold(actions: Array[StringName]) -> void:
	for action in _held:
		if not actions.has(action):
			Input.action_release(action)
	for action in actions:
		if not _held.has(action):
			Input.action_press(action)
	_held = actions.duplicate()


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func current_move(fighter: Fighter) -> StringName:
	var manager := fighter.hitbox_manager
	return manager.current_attack.attack_id if manager.is_attacking() else &""


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			p1.input.command_accepted.connect(func(c: CommandData) -> void: accepted.append(c))
			p2.input.enabled = false
			print("== 1. the fighter has air moves ==")
			var air := p1.get_attack(&"j.P")
			check(air != null, "j.P exists")
			if air != null:
				check(air.guard == AttackData.Guard.HIGH, "an air move is an overhead")
			print("  moves: %d   commands: %d" % [
				p1.fighter_data.moves.size(), p1.fighter_data.commands.size(),
			])
		5:
			print("\n== 2. jumping forward ==")
			hold([&"p1_right", &"p1_up"])
		9:
			check(not p1.is_on_floor(), "left the ground")
			check(p1.get_stance() == CommandData.Stance.AIR, "airborne stance")
			_air_velocity_x = p1.velocity.x
			print("  airborne with velocity x=%.0f" % _air_velocity_x)
			check(_air_velocity_x > 0.0, "carrying forward momentum")
			hold([&"p1_right", &"p1_p"])
		11:
			hold([&"p1_right"])
			print("\n== 3. the button gives the air version ==")
			print("  move %s   accepted %s" % [
				current_move(p1), accepted[0].command_id if accepted.size() > 0 else "-",
			])
			check(accepted.size() == 1, "one command accepted")
			if accepted.size() == 1:
				check(accepted[0].command_id == &"j.P", "P in the air gave j.P, not 5P")
			check(p1.state_machine.current_state.name == &"Attack", "in the attack state")
		13:
			check(
				is_equal_approx(p1.velocity.x, _air_velocity_x),
				"the jump arc survived the attack, x=%.0f" % p1.velocity.x
			)
			check(not p1.is_on_floor(), "still airborne")
		58:
			hold([])
		60:
			print("\n== 4. landing ends the air move ==")
			print("  on floor=%s  state %s  move %s" % [
				p1.is_on_floor(), p1.state_machine.current_state.name, current_move(p1),
			])
			check(p1.is_on_floor(), "landed")
			check(not p1.hitbox_manager.is_attacking(), "the air move ended")
			check(p1.state_machine.current_state.name == &"Idle", "back to neutral")
		70:
			print("\n== 5. an air move beats a crouching guard ==")
			accepted.clear()
			landed.clear()
			p2.input.enabled = true
			p2.health = 10000
			p2.global_position = Vector2(60, 0)
			# p2 faces left, so down-back for it is down plus screen right.
			hold([&"p2_down", &"p2_right"])
			# Drop p1 in next to p2. is_on_floor only updates on the next
			# move_and_slide, so the state change has to wait a frame or the
			# jump impulse fires again.
			p1.global_position = Vector2(10, -50)
			p1.velocity = Vector2(0, 40)
		72:
			check(not p1.is_on_floor(), "p1 is airborne")
			p1.state_machine.transition_to(&"Jump")
			check(p2.is_crouching(), "p2 is crouching")
			check(p2.is_blocking(), "p2 is holding back")
		74:
			hold([&"p2_down", &"p2_right", &"p1_p"])
		76:
			hold([&"p2_down", &"p2_right"])
		80:
			print("  move %s  p1 y=%.0f  hits %d" % [
				current_move(p1), p1.global_position.y, landed.size(),
			])
		84:
			print("  hits %d   p2 health %d   p2 state %s" % [
				landed.size(), p2.health, p2.state_machine.current_state.name,
			])
			check(landed.size() == 1, "the air move connected")
			if landed.size() == 1:
				check(not landed[0].blocked, "a crouching guard does not stop an overhead")
			check(p2.health < 10000, "damage went through")
		90:
			print("\n== 6. double jump ==")
			hold([])
			p1.global_position = Vector2(-200, 0)
			p1.velocity = Vector2.ZERO
			p2.input.enabled = false
		95:
			check(p1.is_on_floor(), "on the ground with a full tank")
			check(p1.air_jumps_left == p1.stats.air_jumps, "air jumps refilled on landing")
			hold([&"p1_up"])
		99:
			check(not p1.is_on_floor(), "first jump left the ground")
			check(p1.air_jumps_left == p1.stats.air_jumps, "the ground jump costs no air jump")
			# Releasing matters: the second jump is a press, not a hold.
			hold([])
		103:
			_air_velocity_x = p1.velocity.y
			hold([&"p1_up"])
		105:
			print("  air jumps left %d   vertical velocity %.0f -> %.0f" % [
				p1.air_jumps_left, _air_velocity_x, p1.velocity.y,
			])
			check(p1.air_jumps_left == 0, "the second jump spent the air jump")
			check(p1.velocity.y < _air_velocity_x, "it pushed the fighter back up")
			hold([])
		108:
			check(not p1.can_air_jump(), "no third jump")
		150:
			print("\n== 7. air dash ==")
			print("  on floor=%s  air dashes %d" % [p1.is_on_floor(), p1.air_dashes_left])
			check(p1.is_on_floor(), "landed again")
			check(p1.air_dashes_left == p1.stats.air_dashes, "air dashes refilled")
			p1.global_position = Vector2(-200, 0)
			hold([&"p1_up"])
		154:
			hold([])
		156:
			# Double tap forward while airborne.
			check(not p1.is_on_floor(), "airborne")
			_air_velocity_x = p1.global_position.x
			hold([&"p1_right"])
		158:
			hold([])
		160:
			hold([&"p1_right"])
		163:
			print("  state %s   air dashes left %d" % [
				p1.state_machine.current_state.name, p1.air_dashes_left,
			])
			check(p1.state_machine.current_state.name == &"AirDash", "the double tap dashed")
			check(p1.air_dashes_left == 0, "the dash was spent")
			check(not p1.gravity_enabled, "gravity is suspended during the dash")
			check(p1.velocity.x > 300.0, "dashing forward fast")
			check(is_zero_approx(p1.velocity.y), "no falling during the dash")
		168:
			# An attack out of a dash keeps the dash momentum.
			hold([&"p1_right", &"p1_p"])
		170:
			hold([&"p1_right"])
			print("  attacking out of the dash: %s  velocity x=%.0f" % [
				current_move(p1), p1.velocity.x,
			])
			check(current_move(p1) == &"j.P", "the air normal came out of the dash")
			check(p1.velocity.x > 300.0, "the dash momentum survived the attack")
		185:
			print("  after the dash: gravity=%s  x travelled %.0f" % [
				p1.gravity_enabled, p1.global_position.x - _air_velocity_x,
			])
			check(p1.gravity_enabled, "gravity came back")
			check(p1.global_position.x - _air_velocity_x > 100.0, "covered real distance")
		190:
			hold([])
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
