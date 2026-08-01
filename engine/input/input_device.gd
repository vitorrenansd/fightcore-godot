class_name InputDevice
extends RefCounted

## Reads one player's InputMap actions and returns a direction plus a button
## bitmask.
##
## It does not know whether the input came from a keyboard, a pad or a
## leverless controller: the InputMap handles that, and it is remappable at
## runtime (see InputBindings). What happens here is SOCD cleaning, which is
## what makes leverless input valid in the first place.

## Action prefix for this player: p1_up, p1_p, p1_k...
var prefix: StringName = &"p1"
var socd_mode: FightInput.SOCD = FightInput.SOCD.NEUTRAL

var _horizontal: int = 0
var _actions: Dictionary = {}


func _init(player_index: int = 0) -> void:
	set_player_index(player_index)


func set_player_index(player_index: int) -> void:
	prefix = StringName("p%d" % (player_index + 1))
	_cache_actions()


## Numpad direction, with SOCD already resolved.
func read_direction() -> int:
	var left := _is_pressed(&"left")
	var right := _is_pressed(&"right")
	var up := _is_pressed(&"up")
	var down := _is_pressed(&"down")

	_horizontal = FightInput.clean_socd(
		left,
		right,
		_is_just_pressed(&"left"),
		_is_just_pressed(&"right"),
		_horizontal,
		socd_mode
	)
	# Vertical always favours up: jumping beats crouching, the way every game
	# in the genre does it.
	var vertical := 0
	if up:
		vertical = 1
	elif down:
		vertical = -1

	return FightInput.direction_from_axis(_horizontal, vertical)


func read_buttons() -> int:
	var buttons := 0
	for button in FightInput.BUTTON_NAMES:
		if _is_pressed(button):
			buttons |= button
	return buttons


## An action not registered in the InputMap simply reads as released instead of
## breaking: bindings may be applied after the fighter enters the scene.
func _is_pressed(key: Variant) -> bool:
	var action: StringName = _actions.get(key, &"")
	return action != &"" and InputMap.has_action(action) and Input.is_action_pressed(action)


func _is_just_pressed(key: Variant) -> bool:
	var action: StringName = _actions.get(key, &"")
	return action != &"" and InputMap.has_action(action) and Input.is_action_just_pressed(action)


func _cache_actions() -> void:
	_actions.clear()
	for direction in [&"up", &"down", &"left", &"right"]:
		_actions[direction] = StringName("%s_%s" % [prefix, direction])
	for button in FightInput.BUTTON_NAMES:
		var suffix: StringName = FightInput.BUTTON_NAMES[button]
		_actions[button] = StringName("%s_%s" % [prefix, String(suffix).to_lower()])
