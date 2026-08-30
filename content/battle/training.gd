extends Node2D

## Training room: playable scene for testing input, frame data and boxes.
##
## Keyboard P1: WASD to move, J=P K=K L=S U=HS I=D
## Keyboard P2: arrows to move, numpad 1..5
## Gamepad:     d-pad or stick, A=P B=K X=S Y=HS RB=D
## D alone is the overhead; forward or back with D throws, and the grab box
## draws purple.
## F1 toggles the box overlay, F2 restarts the match.

const TEAM_COLORS: Array[Color] = [Color(0.0, 0.0, 1.0, 1.0), Color(1.0, 0.0, 0.0, 1.0)]

@onready var battle: BattleManager = $Battle
@onready var rounds: RoundManager = $Rounds
@onready var boxes: DebugBoxRenderer = $DebugBoxes
@onready var readout: Label = $HUD/Readout
@onready var banner: Label = $HUD/Banner

var _last_result: String = ""


func _ready() -> void:
	for index in battle.fighters.size():
		var fighter := battle.fighters[index]
		fighter.visuals.modulate = TEAM_COLORS[index % TEAM_COLORS.size()]
	rounds.round_ended.connect(_on_round_ended)
	rounds.match_ended.connect(_on_match_ended)
	rounds.round_started.connect(func(_number: int) -> void: _last_result = "")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_F1:
			boxes.enabled = not boxes.enabled
		KEY_F2:
			rounds.start_match()


func _physics_process(_delta: float) -> void:
	var lines: PackedStringArray = [_describe_round()]
	for index in battle.fighters.size():
		lines.append(_describe(battle.fighters[index], index))
	readout.text = "\n".join(lines)
	banner.text = _last_result


func _describe_round() -> String:
	return "round %d   time %2d   wins %d-%d   %s" % [
		rounds.round_number,
		rounds.get_seconds_left(),
		rounds.get_wins(0),
		rounds.get_wins(1),
		_phase_name(rounds.phase),
	]


## Enum values from another class are not constant expressions, so these names
## live in a match instead of a const dictionary.
func _phase_name(phase: RoundManager.Phase) -> String:
	match phase:
		RoundManager.Phase.INTRO:
			return "READY"
		RoundManager.Phase.FIGHT:
			return "FIGHT"
		RoundManager.Phase.ROUND_END:
			return "ROUND OVER"
		RoundManager.Phase.MATCH_END:
			return "MATCH OVER"
	return "-"


func _reason_name(reason: RoundManager.EndReason) -> String:
	match reason:
		RoundManager.EndReason.KO:
			return "KO"
		RoundManager.EndReason.TIMEOUT:
			return "TIME OVER"
		RoundManager.EndReason.DRAW:
			return "DRAW"
	return "-"


func _describe(fighter: Fighter, index: int) -> String:
	var manager := fighter.hitbox_manager
	var attack_info := "-"
	if manager.is_attacking():
		attack_info = "%s f%d%s" % [
			manager.current_attack.attack_id,
			manager.attack_frame,
			" C" if manager.is_in_cancel_window() else "",
		]
	return "P%d  health %5d  %-11s  move %-12s  dir %d  hitstop %d  tech %2d  combo %d  juggle %d (x%.2f)" % [
		index + 1,
		fighter.health,
		fighter.state_machine.current_state.name if fighter.state_machine.current_state else "-",
		attack_info,
		fighter.input.get_direction() if fighter.input != null else 5,
		fighter.hitstop_frames,
		fighter.throw_tech_frames,
		fighter.combo_hits,
		fighter.juggle_count,
		fighter.get_juggle_gravity_multiplier(),
	]


func _on_round_ended(winner_team: int, reason: RoundManager.EndReason) -> void:
	var label := _reason_name(reason)
	if winner_team == RoundManager.NO_WINNER:
		_last_result = "%s - DRAW" % label
	else:
		_last_result = "%s - P%d WINS THE ROUND" % [label, winner_team + 1]


func _on_match_ended(winner_team: int) -> void:
	if winner_team == RoundManager.NO_WINNER:
		_last_result = "MATCH DRAW        F2 to restart"
	else:
		_last_result = "P%d WINS THE MATCH        F2 to restart" % [winner_team + 1]
