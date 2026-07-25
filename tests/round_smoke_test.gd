extends SceneTree

## Checks the round flow: intro freeze, KO, reset between rounds, timeout
## decided by health and the end of the match.
##
##   godot --headless --path . --script tests/round_smoke_test.gd

const FIGHTER_SCENE := "res://content/fighters/training_dummy/fighter.tscn"

var battle: BattleManager
var rounds: RoundManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var ok: bool = true

var round_results: Array = []
var match_winner: int = -99


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
	battle.spawn_positions = [Vector2(-120, 0), Vector2(120, 0)]
	root.add_child(battle)

	rounds = RoundManager.new()
	rounds.battle = battle
	# Short phases so the whole match fits in a couple of seconds.
	rounds.intro_frames = 10
	rounds.round_end_frames = 10
	rounds.round_seconds = 1
	rounds.rounds_to_win = 2
	rounds.round_ended.connect(
		func(winner: int, reason: RoundManager.EndReason) -> void:
			round_results.append([winner, reason])
	)
	rounds.match_ended.connect(func(winner: int) -> void: match_winner = winner)
	root.add_child(rounds)


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func phase_name() -> String:
	return RoundManager.Phase.keys()[rounds.phase]


func _physics_process(_delta: float) -> bool:
	frames += 1
	match frames:
		5:
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			print("== 1. intro ==")
			print("  phase %s  round %d  wins %d-%d  time %d" % [
				phase_name(), rounds.round_number, rounds.get_wins(0), rounds.get_wins(1),
				rounds.get_seconds_left(),
			])
			check(rounds.phase == RoundManager.Phase.INTRO, "starts in INTRO")
			check(p1.frozen and p2.frozen, "fighters frozen during the intro")
			check(rounds.get_wins(0) == 0 and rounds.get_wins(1) == 0, "no round wins yet")
			check(not rounds.timer.running, "clock stopped during the intro")
		14:
			print("\n== 2. fight ==")
			print("  phase %s  clock running=%s" % [phase_name(), rounds.timer.running])
			check(rounds.phase == RoundManager.Phase.FIGHT, "INTRO gave way to FIGHT")
			check(not p1.frozen and not p2.frozen, "fighters released")
			check(rounds.timer.running, "clock running")
		15:
			# Forced KO: the round layer only reads is_alive().
			p2.health = 0
		18:
			print("\n== 3. KO ==")
			print("  phase %s  wins %d-%d  results %s" % [
				phase_name(), rounds.get_wins(0), rounds.get_wins(1), round_results,
			])
			check(rounds.phase == RoundManager.Phase.ROUND_END, "round ended")
			check(round_results.size() == 1, "one round result")
			if round_results.size() == 1:
				check(round_results[0][0] == 0, "P1 took the round")
				check(round_results[0][1] == RoundManager.EndReason.KO, "reason was KO")
			check(rounds.get_wins(0) == 1, "P1 has 1 win")
			check(p1.frozen and p2.frozen, "fighters frozen at round end")
		30:
			print("\n== 4. next round ==")
			print("  phase %s  round %d  p2 health %d  p2 x %.0f" % [
				phase_name(), rounds.round_number, p2.health, p2.position.x,
			])
			check(rounds.round_number == 2, "second round started")
			check(rounds.phase == RoundManager.Phase.INTRO, "back to INTRO")
			check(p2.health == p2.stats.max_health, "health restored")
			check(is_equal_approx(p2.position.x, 120.0), "position reset")
			check(p2.state_machine.current_state.name == &"Idle", "state reset")
			# Set up the timeout: P1 ends the round ahead on health.
			p2.health = 5000
		40:
			check(rounds.phase == RoundManager.Phase.FIGHT, "round 2 fighting")
		100:
			print("\n== 5. timeout ==")
			print("  phase %s  wins %d-%d  results %s" % [
				phase_name(), rounds.get_wins(0), rounds.get_wins(1), round_results,
			])
			check(round_results.size() == 2, "two round results")
			if round_results.size() == 2:
				check(round_results[1][0] == 0, "the healthier fighter took it")
				check(round_results[1][1] == RoundManager.EndReason.TIMEOUT, "reason was TIMEOUT")
			check(rounds.get_wins(0) == 2, "P1 has 2 wins")
		115:
			print("\n== 6. match over ==")
			print("  phase %s  winner P%d" % [phase_name(), match_winner + 1])
			check(rounds.phase == RoundManager.Phase.MATCH_END, "match ended")
			check(match_winner == 0, "P1 won the match")
		116:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
