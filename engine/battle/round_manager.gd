class_name RoundManager
extends Node

## Drives the match above the fight itself: rounds, clock and win conditions.
##
## BattleManager owns the fighters and the hit resolution; this class owns the
## rules around them. Splitting the two means a training room can run a match
## with no rounds at all, and a story mode can change the win conditions
## without touching combat.
##
## Every phase is counted in frames, like everything else in the engine.

signal round_started(round_number: int)
signal round_ended(winner_team: int, reason: EndReason)
signal match_ended(winner_team: int)
signal phase_changed(phase: Phase)

enum Phase {
	INTRO, ## Fighters frozen before the round starts.
	FIGHT, ## Clock running, fighters free.
	ROUND_END, ## Pause after a KO or a timeout.
	MATCH_END, ## Someone won the match.
}

enum EndReason {
	KO, ## Someone ran out of health.
	TIMEOUT, ## The clock ran out; the healthier fighter takes it.
	DRAW, ## Double KO or an exact health tie on timeout.
}

## Returned when no side won: a draw.
const NO_WINNER: int = -1

@export var battle: BattleManager
@export var round_seconds: int = 99
@export var rounds_to_win: int = 2
## Frozen frames before the round starts.
@export var intro_frames: int = 60
## Pause after the round ends, before the next one.
@export var round_end_frames: int = 120
@export var auto_start: bool = true

var phase: Phase = Phase.INTRO
var round_number: int = 1
var wins: PackedInt32Array
var timer := RoundTimer.new()

var _phase_frame: int = 0


func _ready() -> void:
	if battle == null:
		battle = find_battle()
	if battle == null:
		push_error("RoundManager: no BattleManager found, the match will not start")
		return
	if auto_start:
		start_match()


## Finds the match this manager drives. Looks at the exported reference first,
## then the parent, then the siblings — so dropping the node next to a
## BattleManager just works, with no wiring.
func find_battle() -> BattleManager:
	var parent := get_parent()
	if parent is BattleManager:
		return parent
	if parent == null:
		return null
	for sibling in parent.get_children():
		if sibling is BattleManager:
			return sibling
	return null


func _physics_process(_delta: float) -> void:
	if battle == null:
		return
	_phase_frame += 1
	match phase:
		Phase.INTRO:
			if _phase_frame >= intro_frames:
				_start_fight()
		Phase.FIGHT:
			_update_fight()
		Phase.ROUND_END:
			if _phase_frame >= round_end_frames:
				_advance_round()
		Phase.MATCH_END:
			pass


func start_match() -> void:
	wins.resize(CollisionLayers.TEAM_COUNT)
	wins.fill(0)
	round_number = 1
	_begin_round()


func get_wins(team: int) -> int:
	return wins[team] if team >= 0 and team < wins.size() else 0


func get_seconds_left() -> int:
	return timer.get_seconds_left()


func is_fighting() -> bool:
	return phase == Phase.FIGHT


func _begin_round() -> void:
	battle.reset_round()
	battle.set_fighters_frozen(true)
	timer.start(round_seconds)
	timer.stop()
	_set_phase(Phase.INTRO)
	round_started.emit(round_number)


func _start_fight() -> void:
	battle.set_fighters_frozen(false)
	timer.resume()
	_set_phase(Phase.FIGHT)


## A KO beats the clock: checked first so a knockout on the very last frame
## still reads as a KO and not as a timeout.
func _update_fight() -> void:
	var knocked_out := _get_knocked_out_teams()
	if not knocked_out.is_empty():
		if knocked_out.size() >= battle.fighters.size():
			_end_round(NO_WINNER, EndReason.DRAW)
		else:
			_end_round(_get_surviving_team(knocked_out), EndReason.KO)
		return
	if timer.tick():
		var winner := _get_healthiest_team()
		_end_round(winner, EndReason.DRAW if winner == NO_WINNER else EndReason.TIMEOUT)


func _end_round(winner_team: int, reason: EndReason) -> void:
	timer.stop()
	battle.set_fighters_frozen(true)
	if winner_team == NO_WINNER:
		# A draw gives both sides the round, the usual double KO rule.
		for team in wins.size():
			wins[team] += 1
	else:
		wins[winner_team] += 1
	_set_phase(Phase.ROUND_END)
	round_ended.emit(winner_team, reason)


func _advance_round() -> void:
	if _is_match_over():
		_set_phase(Phase.MATCH_END)
		match_ended.emit(_get_champion())
		return
	round_number += 1
	_begin_round()


func _is_match_over() -> bool:
	for team in wins.size():
		if wins[team] >= rounds_to_win:
			return true
	return false


## Team with the most round wins, or NO_WINNER when they are level.
func _get_champion() -> int:
	var best := NO_WINNER
	var best_wins := -1
	var tied := false
	for team in wins.size():
		if wins[team] > best_wins:
			best = team
			best_wins = wins[team]
			tied = false
		elif wins[team] == best_wins:
			tied = true
	return NO_WINNER if tied else best


func _get_knocked_out_teams() -> PackedInt32Array:
	var teams := PackedInt32Array()
	for fighter in battle.fighters:
		if not fighter.is_alive():
			teams.append(fighter.team)
	return teams


func _get_surviving_team(knocked_out: PackedInt32Array) -> int:
	for fighter in battle.fighters:
		if not knocked_out.has(fighter.team):
			return fighter.team
	return NO_WINNER


## Compared as a fraction of max health, so characters with different health
## pools are judged fairly on a timeout.
func _get_healthiest_team() -> int:
	var best := NO_WINNER
	var best_ratio := -1.0
	var tied := false
	for fighter in battle.fighters:
		var maximum := fighter.stats.max_health if fighter.stats != null else 1
		var ratio := float(fighter.health) / maxi(maximum, 1)
		if ratio > best_ratio:
			best = fighter.team
			best_ratio = ratio
			tied = false
		elif is_equal_approx(ratio, best_ratio):
			tied = true
	return NO_WINNER if tied else best


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_frame = 0
	phase_changed.emit(new_phase)
