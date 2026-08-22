extends SceneTree

## Checks the system throw: the move every character has without authoring it,
## what it catches, what it whiffs on, and the break when both sides go for it.
##
##   godot --headless --path . --script tests/throw_smoke_test.gd
##
## The throw is the first mechanic the engine ships as content of its own, so
## half of this test is about the delivery — that a fighter whose `FighterData`
## never mentions 6D still answers to it — and the other half about the rules
## that make a grab different from a hit.

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

const NEAR: float = 24.0
const FAR: float = 400.0

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var ok: bool = true

var landed: Array[HitData] = []
var breaks: Array[Array] = []
var accepted: Array[CommandData] = []

## Frames `p1` spent with its throw window open, counted rather than sampled:
## the window is the thing under test, so its length has to be measured.
var counting_tech: bool = false
var tech_frames: int = 0

## Columns before the back throw, so the swap can be checked against them.
var before_p1_x: float = 0.0
var before_p2_x: float = 0.0
var frozen_p1_x: float = 0.0
var frozen_p2_x: float = 0.0

## Set for the follow-up phase: press the fastest button the moment the throw
## lets go, which is the question a combo starter has to answer.
var chasing: bool = false
var chase_recorded: bool = false
var chase_airborne: bool = false
var chase_combo: int = 0
var chase_attacks: int = 0
## Latched: a throw has to end on the floor even when a combo came off it.
var saw_knockdown: bool = false

## Actions held this frame, refreshed every frame so Godot sees the releases.
var _held: Array[StringName] = []


func _initialize() -> void:
	var scene: PackedScene = load(FIGHTER_SCENE)
	battle = BattleManager.new()
	battle.fighter_scenes = [scene, scene]
	battle.spawn_positions = [Vector2(-NEAR, 0), Vector2(NEAR, 0)]
	battle.hit_resolved.connect(func(hit: HitData) -> void: landed.append(hit))
	battle.throw_broken.connect(
		func(first: Fighter, second: Fighter) -> void: breaks.append([first, second])
	)
	root.add_child(battle)

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 70)
	root.add_child(floor_body)


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func hold(actions: Array[StringName]) -> void:
	for action in _held:
		if not actions.has(action):
			Input.action_release(action)
	for action in actions:
		if not _held.has(action):
			Input.action_press(action)
	_held = actions.duplicate()


## Both fighters back to neutral, at the given distance from the centre.
func reset_pair(distance: float) -> void:
	landed.clear()
	breaks.clear()
	for fighter in [p1, p2]:
		fighter.reset_for_round()
	p1.position = Vector2(-distance, 0.0)
	p2.position = Vector2(distance, 0.0)
	p1.set_facing(true)
	p2.set_facing(false)


func throw_with(fighter: Fighter, attack_id: StringName) -> bool:
	return fighter.perform_attack(fighter.get_attack(attack_id))


func has_command(fighter: Fighter, command_id: StringName) -> bool:
	for command in fighter.commands:
		if command.command_id == command_id:
			return true
	return false


func _observe() -> void:
	if counting_tech and p1.is_teching_throw():
		tech_frames += 1
	if not chasing:
		return
	# Exactly one follow-up, which is the case that was reported broken: 6D into
	# 5P and nothing else.
	if chase_attacks < 1 and p1.can_act() and not p1.hitbox_manager.is_attacking():
		if p1.perform_attack(p1.get_attack(&"5P")):
			chase_attacks += 1
	if landed.size() >= 2 and not chase_recorded:
		chase_recorded = true
		chase_airborne = not p2.is_on_floor()
		chase_combo = p2.combo_hits
	if p2.is_knocked_down():
		saw_knockdown = true


func _physics_process(_delta: float) -> bool:
	frames += 1
	if p1 == null:
		p1 = battle.get_fighter(0)
		p2 = battle.get_fighter(1)
		p1.input.command_accepted.connect(func(c: CommandData) -> void: accepted.append(c))
		p2.input.enabled = false
	match frames:
		2:
			print("== 1. every character has the throw without authoring it ==")
			var authored := p1.fighter_data.commands.size()
			print("  authored commands %d   answered to %d" % [authored, p1.commands.size()])
			check(not has_command_in(p1.fighter_data.commands, &"6D"),
				"the character never authored 6D")
			check(has_command(p1, &"6D") and has_command(p1, &"4D"),
				"both throws reached the fighter's command list")
			var forward := p1.get_attack(&"6D")
			check(forward != null, "6D resolves to an attack")
			if forward != null:
				print("  6D: %s  %df startup  %df active  %df recovery  tech %df" % [
					forward.display_name, forward.startup_frames, forward.active_frames,
					forward.recovery_frames, forward.throw_tech_frames,
				])
				check(forward.is_throw, "6D is a throw")
				check(forward.guard == AttackData.Guard.UNBLOCKABLE, "a throw ignores the guard")
				check(forward.throw_tech_frames == 10, "the tech window is 10 frames")
			# Without this 5D and 6D tie and the list order decides which comes out.
			check(command_priority(p1, &"6D") > command_priority(p1, &"5D"),
				"6D outranks 5D on the same button")

			print("\n== 2. the throw window lasts exactly its authored count ==")
			reset_pair(FAR)
			counting_tech = true
			check(throw_with(p1, &"6D"), "the throw came out")
		30:
			counting_tech = false
			print("  window open for %d frames   still open now %s" % [
				tech_frames, p1.is_teching_throw(),
			])
			check(tech_frames == 10, "the window lasted 10 frames, got %d" % tech_frames)
			check(not p1.is_teching_throw(), "the window closed on its own")
			check(landed.is_empty(), "a throw out of range catches nobody")
		60:
			print("\n== 3. a throw goes through a guard ==")
			reset_pair(NEAR)
			# The only phase where p2 does anything, and all it does is guard.
			p2.input.enabled = true
			# Down-back, not back: holding plain back walks away, and at this range
			# that is enough to leave the grab box. Crouch blocking guards without
			# giving ground, which is the situation the throw exists to answer.
			hold([&"p2_down", &"p2_right"])
		62:
			check(p2.is_blocking(), "p2 is guarding")
			check(throw_with(p1, &"6D"), "the throw came out")
		75:
			print("  hits %d   p2 health %d   p2 %s" % [
				landed.size(), p2.health, p2.state_machine.current_state.name,
			])
			check(landed.size() == 1, "the throw connected")
			if landed.size() == 1:
				check(not landed[0].blocked, "guarding does not stop a throw")
				check(landed[0].knockdown, "the throw puts them on the floor")
			check(p2.health < p2.stats.max_health, "damage applied through the guard")
			hold([])
			p2.input.enabled = false
		120:
			print("\n== 4. a throw whiffs on an airborne opponent ==")
			reset_pair(NEAR)
			# A low hop: off the floor, but still inside the grab box.
			p2.velocity.y = -150.0
		122:
			check(throw_with(p1, &"6D"), "the throw came out")
		130:
			print("  p2 airborne %s   y %.1f   hits %d" % [
				not p2.is_on_floor(), p2.position.y, landed.size(),
			])
			check(not p2.is_on_floor(), "p2 left the ground")
			check(landed.is_empty(), "nobody grabs an airborne fighter")
			check(p2.health == p2.stats.max_health, "no damage")
		170:
			print("\n== 5. a throw whiffs on someone already in hitstun ==")
			reset_pair(NEAR)
			var stun := p2.state_machine.get_state(&"Hitstun") as FighterHitstunState
			stun.start_hitstun(40, false)
			p2.state_machine.transition_to(&"Hitstun")
		172:
			check(throw_with(p1, &"6D"), "the throw came out")
		185:
			print("  p2 %s   hits %d" % [p2.state_machine.current_state.name, landed.size()])
			check(p2.is_in_hitstun(), "p2 still in hitstun")
			check(landed.is_empty(), "a combo victim cannot be grabbed")
		220:
			print("\n== 6. both go for the throw: neither one lands ==")
			reset_pair(NEAR)
			check(throw_with(p1, &"6D"), "p1 threw")
		224:
			# Four frames later, well inside the ten frame window.
			check(throw_with(p2, &"6D"), "p2 answered with a throw")
		226:
			print("  breaks %d   hits %d   p1 %s   p2 %s   push %.0f / %.0f" % [
				breaks.size(), landed.size(),
				p1.state_machine.current_state.name, p2.state_machine.current_state.name,
				p1.velocity.x, p2.velocity.x,
			])
			check(breaks.size() == 1, "one break, not one per side")
			check(landed.is_empty(), "no throw connected")
			check(p1.health == p1.stats.max_health and p2.health == p2.stats.max_health,
				"a break costs nobody any health")
			check(p1.is_throw_broken() and p2.is_throw_broken(), "both in ThrowBreak")
			check(not p1.hitbox_manager.is_attacking() and not p2.hitbox_manager.is_attacking(),
				"both throws were dropped")
			check(is_equal_approx(p1.velocity.x, -p2.velocity.x), "pushed apart equally")
			check(p1.velocity.x < 0.0 and p2.velocity.x > 0.0, "pushed away from each other")
			check(p1.hitstop_frames > 0 and p2.hitstop_frames > 0, "both froze on the break")
		250:
			check(p1.is_throw_broken() and p2.is_throw_broken(), "the lockout is still running")
			check(not p1.can_act() and not p2.can_act(), "neither can act during the break")
		270:
			print("  after the break: p1 x %.2f   p2 x %.2f   states %s / %s" % [
				p1.position.x, p2.position.x,
				p1.state_machine.current_state.name, p2.state_machine.current_state.name,
			])
			check(not p1.is_throw_broken() and not p2.is_throw_broken(), "both recovered")
			check(p1.can_act() and p2.can_act(), "and recovered together")
			check(is_equal_approx(absf(p1.position.x), absf(p2.position.x)),
				"both ended the same distance from where they started")
			check(absf(p1.position.x) > NEAR, "the break actually pushed them apart")
		300:
			print("\n== 7. once the window is over, the whiffed throw is the punish ==")
			reset_pair(FAR)
			check(throw_with(p2, &"6D"), "p2 threw at nothing")
		312:
			# Twelve frames later: p2's window is closed, its recovery is not.
			check(not p2.is_teching_throw(), "p2's window has closed")
			check(p2.hitbox_manager.is_attacking(), "p2 is still recovering")
			p1.position = Vector2(-NEAR, 0.0)
			p2.position = Vector2(NEAR, 0.0)
			check(throw_with(p1, &"6D"), "p1 threw")
		325:
			print("  breaks %d   hits %d   p2 health %d" % [
				breaks.size(), landed.size(), p2.health,
			])
			check(breaks.is_empty(), "a closed window does not break anything")
			check(landed.size() == 1, "the throw landed")
			check(p2.health < p2.stats.max_health, "the whiffed throw got punished")
		340:
			print("\n== 8. the back throw sends them behind the attacker ==")
			reset_pair(NEAR)
		342:
			before_p1_x = p1.position.x
			before_p2_x = p2.position.x
			check(p1.facing_right and not p2.facing_right, "p1 starts on the left")
			check(throw_with(p1, &"4D"), "p1 threw backwards")
		350:
			print("  before  p1 %.0f / p2 %.0f      after  p1 %.0f / p2 %.0f" % [
				before_p1_x, before_p2_x, p1.position.x, p2.position.x,
			])
			print("  facing  p1 %s   p2 %s" % [
				"right" if p1.facing_right else "left",
				"right" if p2.facing_right else "left",
			])
			check(landed.size() == 1, "the back throw connected")
			check(is_equal_approx(p1.position.x, before_p2_x), "p1 took the opponent's column")
			check(is_equal_approx(p2.position.x, before_p1_x), "the opponent took p1's")
			check(not p1.facing_right and p2.facing_right, "both turned to face the new sides")
			check(p1.hitstop_frames > 0 and p2.hitstop_frames > 0, "both held after the swap")
			frozen_p1_x = p1.position.x
			frozen_p2_x = p2.position.x
		365:
			# Still inside the freeze the back throw authors, which is longer than
			# the forward one: a side switch has to be readable, and later it is
			# where the animation goes.
			print("  freeze at f365: p1 hitstop %d   p2 hitstop %d" % [
				p1.hitstop_frames, p2.hitstop_frames,
			])
			check(p1.hitstop_frames > 0 and p2.hitstop_frames > 0, "the hold is still running")
			check(is_equal_approx(p1.position.x, frozen_p1_x)
				and is_equal_approx(p2.position.x, frozen_p2_x),
				"neither one drifts during the hold")
		400:
			print("\n== 9. the input: 6D, 4D and 5D on the same button ==")
			reset_pair(FAR)
			accepted.clear()
			hold([&"p1_right", &"p1_d"])
		403:
			hold([])
			check(accepted.size() == 1, "one command accepted")
			if accepted.size() == 1:
				print("  forward + D gave %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"6D", "forward + D is the throw, not the dust")
		440:
			reset_pair(FAR)
			accepted.clear()
			hold([&"p1_left", &"p1_d"])
		443:
			hold([])
			check(accepted.size() == 1, "one command accepted")
			if accepted.size() == 1:
				print("  back + D gave %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"4D", "back + D is the back throw")
		480:
			reset_pair(FAR)
			accepted.clear()
			hold([&"p1_d"])
		483:
			hold([])
			check(accepted.size() == 1, "one command accepted")
			if accepted.size() == 1:
				print("  D alone gave %s" % accepted[0].command_id)
				check(accepted[0].command_id == &"5D", "D alone is still the dust")
		520:
			print("\n== 10. the throw leaves a window to keep going ==")
			reset_pair(NEAR)
			chase_recorded = false
			chasing = true
			check(throw_with(p1, &"6D"), "p1 threw")
		580:
			print("  hits %d   combo %d   caught airborne %s   p2 health %d" % [
				landed.size(), chase_combo, chase_airborne, p2.health,
			])
			check(landed.size() >= 2, "a throw is a starter: something connected after it")
			check(chase_airborne, "the follow-up caught them before they landed")
			check(chase_combo >= 2, "it counted as a combo, not as a fresh hit")
		640:
			chasing = false
			print("  after the combo: p2 %s   went down at some point %s" % [
				p2.state_machine.current_state.name, saw_knockdown,
			])
			check(saw_knockdown, "a throw ends on the floor even when a combo came off it")
		660:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	# After the frame's work, never before: this script runs once the whole tree
	# has already updated, so observing here is what the CollisionSolver sees on
	# the same frame — including a throw started by this very frame's block.
	_observe()
	return false


func has_command_in(commands: Array[CommandData], command_id: StringName) -> bool:
	for command in commands:
		if command.command_id == command_id:
			return true
	return false


func command_priority(fighter: Fighter, command_id: StringName) -> int:
	for command in fighter.commands:
		if command.command_id == command_id:
			return command.get_effective_priority()
	return -1
