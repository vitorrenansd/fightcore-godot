extends SceneTree

## End-to-end input check with simulated input: buffer, SOCD, motion
## recognition and the move coming out through the attack state.
##
##   godot --headless --path . --script tests/input_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var landed: Array[HitData] = []
var accepted: Array[CommandData] = []
var ok: bool = true

## Actions held this frame, refreshed every frame so Godot sees presses and
## releases correctly.
var _held: Array[StringName] = []


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(-60, 0), Vector2(60, 0)]
	battle.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))
	root.add_child(battle)

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)


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


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		1:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			p1.input.command_accepted.connect(func(c: CommandData) -> void: accepted.append(c))
			# The dummy does not react: only p1 takes commands in this test.
			p2.input.enabled = false
			print("== 1. actions registered in the InputMap ==")
			for action in [&"p1_left", &"p1_right", &"p1_up", &"p1_down", &"p1_p", &"p1_k", &"p1_s", &"p1_hs", &"p1_d"]:
				check(InputMap.has_action(action), "action %s registered" % action)
			check(not Input.use_accumulated_input, "accumulated input disabled")
			print("  %d actions in the map" % InputMap.get_actions().size())

			print("\n== 2. SOCD: left + right at the same time ==")
			hold([&"p1_left", &"p1_right"])
		3:
			print("  direction with both sides held: %d" % p1.input.get_direction())
			check(p1.input.get_direction() == FightInput.NEUTRAL, "opposites cancel out (neutral)")
			hold([&"p1_right"])
		6:
			check(p1.input.get_direction() == 6, "right alone = 6")
			check(p1.state_machine.current_state.name == &"Walk", "walking forward")
			hold([&"p1_down"])
		9:
			check(p1.input.get_direction() == 2, "down = 2")
			check(p1.state_machine.current_state.name == &"Crouch", "crouching")
			check(p1.get_stance() == CommandData.Stance.CROUCH, "crouching stance")

			print("\n== 3. low move by stance: 2K ==")
			hold([&"p1_down", &"p1_k"])
		11:
			check(accepted.size() == 1, "one command accepted")
			if accepted.size() == 1:
				print("  command: %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"2K", "crouch + K gave 2K, not 5K")
			check(p1.state_machine.current_state.name == &"Attack", "entered Attack")
			hold([])
		30:
			print("\n== 4. buffer: button pressed before the fighter can act ==")
			accepted.clear()
			check(p1.can_act(), "p1 free")
			hold([&"p1_hs"])
		31:
			hold([])
			check(accepted.size() == 1 and accepted[0].command_id == &"5HS", "5HS came out")
			# 5HS is 40 frames total; the P pressed now lands mid-move and would
			# have to survive until recovery ends.
		34:
			hold([&"p1_p"])
		35:
			hold([])
			check(accepted.size() == 1, "a press mid-move does not fire right away")
		42:
			print("  commands accepted so far: %d (the 8 frame buffer already expired)" % accepted.size())
			check(accepted.size() == 1, "the 8 frame buffer expires, it does not hold forever")

		75:
			print("\n== 5. motion: 236 + S ==")
			accepted.clear()
			hold([&"p1_down"])
		77:
			hold([&"p1_down", &"p1_right"])
		79:
			hold([&"p1_right"])
		81:
			hold([&"p1_right", &"p1_s"])
		83:
			hold([])
			check(accepted.size() == 1, "one command accepted for 236S")
			if accepted.size() == 1:
				print("  command: %s (priority %d)" % [
					accepted[0].command_id, accepted[0].get_effective_priority(),
				])
				check(accepted[0].command_id == &"236S", "236+S gave the special, not 5S")
		130:
			print("\n== 6. skipped diagonal still counts (2 -> 6, no 3) ==")
			accepted.clear()
			hold([&"p1_down"])
		133:
			hold([&"p1_right"])
		135:
			hold([&"p1_right", &"p1_s"])
		137:
			hold([])
			if accepted.size() == 1:
				print("  command: %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"236S", "quarter circle without the diagonal still comes out")
			else:
				check(false, "no command accepted with the diagonal skipped")
		185:
			print("\n== 7. the move connects with the opponent ==")
			landed.clear()
			p1.position = Vector2(-60, 0)
			p2.position = Vector2(10, 0)
		187:
			hold([&"p1_s"])
		188:
			hold([])
		200:
			print("  hits: %d  p2 health: %d" % [landed.size(), p2.health])
			check(landed.size() == 1, "5S connected")
			check(p2.health < 10000, "damage applied")
		201:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
