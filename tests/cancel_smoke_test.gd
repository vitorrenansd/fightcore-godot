extends SceneTree

## Checks the cancel rules: gatling ladder, special cancel, the whiff block and
## the cancel window.
##
##   godot --headless --path . --script tests/cancel_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var accepted: Array[CommandData] = []
var ok: bool = true

var _held: Array[StringName] = []


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
	# Point blank, so every move connects and opens its cancel window.
	battle.spawn_positions = [Vector2(-30, 0), Vector2(30, 0)]
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

			print("== 1. cancel rules on the data ==")
			var jab := p1.get_attack(&"5P")
			var kick := p1.get_attack(&"5K")
			var heavy := p1.get_attack(&"5HS")
			var special := p1.get_attack(&"236S")
			check(jab.can_cancel_into(kick), "5P cancels into 5K, going up the ladder")
			check(not kick.can_cancel_into(jab), "5K does not cancel back into 5P")
			check(not jab.can_cancel_into(jab), "a move does not cancel into itself")
			check(jab.can_cancel_into(special), "a normal cancels into a special")
			check(not special.can_cancel_into(heavy), "a special does not cancel into a normal")
			print("  levels: 5P=%d 5K=%d 5HS=%d | 236S type=%d" % [
				jab.cancel_level, kick.cancel_level, heavy.cancel_level, special.cancel_type,
			])
		3:
			print("\n== 2. whiffed move does not cancel ==")
			# Far apart: the move touches nothing.
			p1.position = Vector2(-400, 0)
			p2.position = Vector2(400, 0)
		6:
			hold([&"p1_p"])
		7:
			hold([])
			check(current_move(p1) == &"5P", "5P came out")
		12:
			check(not p1.hitbox_manager.has_connected, "the move whiffed")
			check(not p1.hitbox_manager.is_in_cancel_window(), "a whiff opens no cancel window")
			check(not p1.can_start_attack(p1.get_attack(&"5K")), "cannot cancel a whiffed move")
			hold([&"p1_k"])
		13:
			hold([])
		14:
			check(current_move(p1) == &"5P", "5K did not interrupt the whiffed 5P")
		40:
			print("\n== 3. gatling on hit: 5P into 5K ==")
			accepted.clear()
			p1.position = Vector2(-30, 0)
			p2.position = Vector2(30, 0)
			p2.health = 10000
		43:
			hold([&"p1_p"])
		44:
			hold([])
		48:
			# 5P: startup 4, so by now it has connected.
			check(p1.hitbox_manager.has_connected, "5P connected")
			check(p1.hitbox_manager.is_in_cancel_window(), "the cancel window opened")
			print("  frame %d: move %s connected=%s" % [
				p1.hitbox_manager.attack_frame,
				current_move(p1),
				p1.hitbox_manager.has_connected,
			])
			hold([&"p1_k"])
		49:
			hold([])
		52:
			# Still frozen: hitstop holds both sides for 5 frames, so the cancel
			# is waiting in the buffer rather than lost.
			check(p1.hitstop_frames > 0, "still in hitstop")
			check(current_move(p1) == &"5P", "5P has not been cancelled during hitstop")
		56:
			print("  after the cancel: move %s frame %d" % [
				current_move(p1), p1.hitbox_manager.attack_frame,
			])
			check(current_move(p1) == &"5K", "5P cancelled into 5K")
			check(p1.hitbox_manager.attack_frame <= 2, "the new move restarted from the top")
			check(accepted.size() == 2, "two commands accepted, got %d" % accepted.size())
		70:
			print("\n== 4. the cancelled move keeps comboing ==")
			print("  p2 health %d combo %d state %s" % [
				p2.health, p2.combo_hits, p2.state_machine.current_state.name,
			])
			check(p2.combo_hits >= 2, "combo counted both hits, got %d" % p2.combo_hits)
			check(p2.health < 9700, "both hits did damage")
		100:
			print("\n== 5. special cancel: 5S into 236S ==")
			accepted.clear()
			p1.position = Vector2(-30, 0)
			p2.position = Vector2(30, 0)
			p2.health = 10000
		103:
			hold([&"p1_s"])
		104:
			hold([])
		114:
			check(current_move(p1) == &"5S", "5S is running, got %s" % current_move(p1))
			# Quarter circle forward during the move, then the button.
			hold([&"p1_down"])
		116:
			hold([&"p1_down", &"p1_right"])
		118:
			hold([&"p1_right"])
		120:
			hold([&"p1_right", &"p1_s"])
		122:
			hold([])
			print("  move after the motion: %s" % current_move(p1))
			check(current_move(p1) == &"236S", "5S cancelled into the special")
			check(accepted.size() == 2, "two commands accepted, got %d" % accepted.size())
		170:
			print("\n== 6. jump cancel: 5D launches into an air combo ==")
			accepted.clear()
			p1.position = Vector2(-30, 0)
			p2.position = Vector2(30, 0)
			p2.health = 10000
		173:
			check(p1.get_attack(&"5D").jump_cancellable, "5D is jump cancellable")
			check(not p1.get_attack(&"5P").jump_cancellable, "a plain jab is not")
			hold([&"p1_d"])
		174:
			hold([])
		196:
			# 5D has 20 frames of startup, so it has connected by now.
			print("  move %s  connected=%s  p2 y=%.0f" % [
				current_move(p1), p1.hitbox_manager.has_connected, p2.global_position.y,
			])
			check(current_move(p1) == &"5D", "5D is running")
			check(p1.hitbox_manager.has_connected, "5D connected")
			check(p1.can_jump_cancel(), "the jump cancel window is open")
			hold([&"p1_up"])
		205:
			print("  after holding up: state %s  on floor=%s  attacking=%s" % [
				p1.state_machine.current_state.name, p1.is_on_floor(),
				p1.hitbox_manager.is_attacking(),
			])
			check(not p1.is_on_floor(), "jumped straight out of the move")
			check(not p1.hitbox_manager.is_attacking(), "the launcher was cut short")
			hold([&"p1_up", &"p1_p"])
		207:
			hold([])
		209:
			print("  air follow-up: %s" % current_move(p1))
			check(current_move(p1) == &"j.P", "the air normal came out after the jump")
			check(accepted.size() == 2, "two commands accepted, got %d" % accepted.size())
		215:
			print("  p2 health %d  combo %d  p2 y=%.0f" % [
				p2.health, p2.combo_hits, p2.global_position.y,
			])
			# Checked here and not during hitstop: nothing moves while frozen.
			check(p2.global_position.y < -10.0, "the launcher sent the opponent up")
			check(p2.combo_hits >= 2, "the air hit continued the combo, got %d" % p2.combo_hits)
		216:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
