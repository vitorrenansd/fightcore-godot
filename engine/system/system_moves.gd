class_name SystemMoves
extends Resource

## Moves every character has, whoever they are.
##
## These are engine rules and not character design: a fighter can no more opt
## out of the throw than they can opt out of blocking. That is why they live
## here instead of being copied into each `FighterData` — a character added
## tomorrow gets them without touching a single resource, and a character cannot
## be shipped missing one.
##
## They are still authored as a `.tres` like all other frame data. What makes
## them system moves is where they live, not how they are written: nothing in
## the engine holds a startup or a damage number as a script constant.
##
## `Fighter` merges `commands` into its own list on `_ready`, and a system
## command wins a tie against a character command through the usual priority
## rule, not through the merge order.

## Path of the shared instance. A constant and not an export because there is
## exactly one set of system moves in a build: two would mean two answers to
## "what does 6D do", and the point of the mechanic is that there is one.
const RESOURCE_PATH: String = "res://engine/system/system_moves.tres"

@export var commands: Array[CommandData] = []

static var _shared: SystemMoves


## The one shared set. Loaded once and reused: the resource holds no runtime
## state, so every fighter in every match can read the same instance.
static func get_shared() -> SystemMoves:
	if _shared == null:
		_shared = load(RESOURCE_PATH) as SystemMoves
		if _shared == null:
			push_error("SystemMoves: %s did not load, no fighter has system moves" % RESOURCE_PATH)
			_shared = SystemMoves.new()
	return _shared


## Attack behind a system command, by id. Used by tests and scripted setups that
## want the throw without going through the input layer.
func get_attack(attack_id: StringName) -> AttackData:
	for command in commands:
		if command != null and command.attack != null and command.attack.attack_id == attack_id:
			return command.attack
	return null
