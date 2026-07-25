extends Node2D

## Training room: playable scene for testing input, frame data and boxes.
##
## Keyboard P1: WASD to move, J=P K=K L=S U=HS I=D
## Keyboard P2: arrows to move, numpad 1..5
## Gamepad:     d-pad or stick, A=P B=K X=S Y=HS RB=D
## F1 toggles the box overlay.

const TEAM_COLORS: Array[Color] = [Color(0.6, 0.8, 1.0), Color(1.0, 0.7, 0.6)]

@onready var battle: BattleManager = $Battle
@onready var boxes: DebugBoxRenderer = $DebugBoxes
@onready var readout: Label = $HUD/Readout


func _ready() -> void:
	for index in battle.fighters.size():
		var fighter := battle.fighters[index]
		fighter.visuals.modulate = TEAM_COLORS[index % TEAM_COLORS.size()]


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		boxes.enabled = not boxes.enabled


func _physics_process(_delta: float) -> void:
	var lines: PackedStringArray = []
	for index in battle.fighters.size():
		lines.append(_describe(battle.fighters[index], index))
	readout.text = "\n".join(lines)


func _describe(fighter: Fighter, index: int) -> String:
	var manager := fighter.hitbox_manager
	var attack_info := "-"
	if manager.is_attacking():
		attack_info = "%s f%d" % [manager.current_attack.attack_id, manager.attack_frame]
	return "P%d  health %5d  %-8s  move %-10s  dir %d  hitstop %d  combo %d" % [
		index + 1,
		fighter.health,
		fighter.state_machine.current_state.name if fighter.state_machine.current_state else "-",
		attack_info,
		fighter.input.get_direction() if fighter.input != null else 5,
		fighter.hitstop_frames,
		fighter.combo_hits,
	]
