extends SceneTree

## Runs the shipped training room, `content/battle/training.tscn`, exactly as
## the game launches it.
##
##   godot --headless --path . --script tests/training_scene_smoke_test.gd
##
## Every other smoke test builds the match by hand: it news up a BattleManager,
## a floor and two fighters, then drives them. That proves the engine works but
## says nothing about the scene the player actually loads. This one instantiates
## the real `.tscn` and touches nothing, so it covers what only the scene can
## break — the node wiring, the stage's own floor, the room script finding its
## children, and the match numbers as authored rather than as overridden by a
## test.
##
## `--quit-after` catches a crash here, but it cannot tell "the scene ran" from
## "the scene ran and did the right thing". That gap is what this closes.
##
## The clock is left at its authored 99 seconds instead of being shortened, so
## the round transitions are driven by a forced KO. Waiting out a real timeout
## would cost 5940 frames per round and prove nothing the round smoke test does
## not already prove.

const SCENE_PATH := "res://content/battle/training.tscn"

var room: Node = null
var battle: BattleManager
var rounds: RoundManager
var p1: Fighter
var p2: Fighter
var frames: int = 0
var ok: bool = true

## Landing is observed rather than predicted: the fighters spawn above the
## stage floor, so when they touch down depends on the stage geometry and the
## character's gravity, both of which are content and free to change.
var p1_landed: int = 0
var p2_landed: int = 0


func _initialize() -> void:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null:
		print("  FAIL: %s did not load" % SCENE_PATH)
		quit(1)
		return
	room = scene.instantiate()
	root.add_child(room)


func check(condition: bool, message: String) -> void:
	if not condition:
		ok = false
		print("  FAIL: %s" % message)


func _observe() -> void:
	if p1 != null and p1_landed == 0 and p1.is_on_floor():
		p1_landed = frames
	if p2 != null and p2_landed == 0 and p2.is_on_floor():
		p2_landed = frames


func _physics_process(_delta: float) -> bool:
	frames += 1
	_observe()
	match frames:
		5:
			battle = room.battle
			rounds = room.rounds
			p1 = battle.get_fighter(0)
			p2 = battle.get_fighter(1)
			print("== 1. the scene wires itself ==")
			print("  fighters %d   boxes %s   rounds found battle %s" % [
				battle.fighters.size(), room.boxes != null, rounds.battle == battle,
			])
			check(battle != null and rounds != null, "Battle and Rounds resolved")
			check(battle.fighters.size() == 2, "two fighters spawned from the scene")
			# RoundManager has no NodePath to its match: it finds the sibling.
			check(rounds.battle == battle, "RoundManager found the BattleManager")
			check(p1 != null and p2 != null, "both teams have a fighter")
			check(p1.team == 0 and p2.team == 1, "teams assigned 0 and 1")
			check(p1.opponent == p2 and p2.opponent == p1, "fighters paired")
			check(room.boxes != null, "debug box renderer present")
			check(room.readout != null and room.banner != null, "HUD labels present")
		30:
			print("\n== 2. the room script ran over the real fighters ==")
			print("  p1 tint %s   p2 tint %s" % [p1.visuals.modulate, p2.visuals.modulate])
			check(p1.visuals.modulate != p2.visuals.modulate, "team colours differ")
			check(p1.visuals.modulate != Color.WHITE, "team colour applied to P1")
			# Frozen means no gravity, so the intro holds them where they spawned.
			check(rounds.phase == RoundManager.Phase.INTRO, "still in the intro")
			check(p1.frozen and p2.frozen, "fighters frozen through the intro")
			check(is_equal_approx(p1.position.y, 0.0), "the freeze suspends gravity")
		62:
			print("\n== 3. the authored match config is what runs ==")
			print("  round %ds   intro %df   round end %df   first to %d" % [
				rounds.round_seconds, rounds.intro_frames,
				rounds.round_end_frames, rounds.rounds_to_win,
			])
			check(rounds.round_seconds == 99, "99 second rounds")
			check(rounds.rounds_to_win == 2, "first to 2 rounds")
			check(rounds.auto_start, "the match starts on its own")
			check(rounds.phase == RoundManager.Phase.FIGHT, "intro gave way to FIGHT")
			check(not p1.frozen and not p2.frozen, "fighters released")
			check(rounds.get_seconds_left() == 99, "clock starts full")
		120:
			print("\n== 4. the stage's own floor catches them ==")
			print("  landed on f%d and f%d   y %.0f   x %.0f / %.0f" % [
				p1_landed, p2_landed, p1.position.y, p1.position.x, p2.position.x,
			])
			check(p1_landed > 0 and p2_landed > 0, "both fighters reached the floor")
			check(p1_landed > 60, "they only fall once the intro releases them")
			check(p1.is_on_floor() and p2.is_on_floor(), "still standing on it")
			check(is_equal_approx(p1.position.x, -140.0), "P1 held its spawn column")
			check(is_equal_approx(p2.position.x, 140.0), "P2 held its spawn column")
			check(p1.state_machine.current_state.name == &"Idle", "landed into Idle")
		125:
			# The round layer only reads is_alive(), so this is a clean KO.
			p2.health = 0
		130:
			print("\n== 5. a KO ends the round inside the real scene ==")
			print("  phase %d   wins %d-%d   banner %s" % [
				rounds.phase, rounds.get_wins(0), rounds.get_wins(1),
				JSON.stringify(room.banner.text),
			])
			check(rounds.phase == RoundManager.Phase.ROUND_END, "round ended")
			check(rounds.get_wins(0) == 1 and rounds.get_wins(1) == 0, "P1 took the round")
			check(room.banner.text.contains("KO"), "the room announced the KO")
			check(p1.frozen and p2.frozen, "fighters frozen at round end")
		260:
			print("\n== 6. the next round resets the scene ==")
			print("  round %d   phase %d   p2 health %d   p2 pos %s" % [
				rounds.round_number, rounds.phase, p2.health, p2.position,
			])
			check(rounds.round_number == 2, "second round started")
			check(rounds.phase == RoundManager.Phase.INTRO, "back to the intro")
			check(p2.health == p2.stats.max_health, "health restored")
			check(is_equal_approx(p2.position.x, 140.0), "spawn position restored")
			check(p2.state_machine.current_state.name == &"Idle", "state restored")
			check(rounds.get_wins(0) == 1, "round wins carried over")
		315:
			print("\n== 7. the HUD reports the live match ==")
			print("  %s" % room.readout.text.replace("\n", "\n  "))
			check(rounds.phase == RoundManager.Phase.FIGHT, "round 2 fighting")
			check(room.readout.text.contains("round 2"), "readout shows the round")
			check(room.readout.text.contains("P1") and room.readout.text.contains("P2"),
				"readout shows both fighters")
			check(room.readout.text.contains("juggle"), "readout shows the juggle counter")
			# F2 in the room: restarting has to clear the score, not add to it.
			rounds.start_match()
		320:
			print("\n== 8. restarting clears the match ==")
			print("  round %d   phase %d   wins %d-%d" % [
				rounds.round_number, rounds.phase,
				rounds.get_wins(0), rounds.get_wins(1),
			])
			check(rounds.round_number == 1, "back to round 1")
			check(rounds.get_wins(0) == 0 and rounds.get_wins(1) == 0, "score cleared")
			check(rounds.phase == RoundManager.Phase.INTRO, "restarted into the intro")
			check(p1.health == p1.stats.max_health, "health restored on restart")
		325:
			print("\nRESULT: %s" % ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	return false
