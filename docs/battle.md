# Match

`BattleManager` (`engine/battle/battle_manager.gd`) owns the match: it spawns
the fighters, assigns teams, links the opponents and runs the
`CollisionSolver`. It is the only place in the engine that knows there are two
sides.

Rounds, timer and score do **not** live here — those belong to `RoundManager`,
still a stub.

## Setup

```gdscript
var battle := BattleManager.new()
battle.fighter_scenes = [p1_scene, p2_scene]
battle.spawn_positions = [Vector2(-120, 0), Vector2(120, 0)]
add_child(battle)
```

With `start_on_ready` (the default) the match starts by itself as soon as the
node enters the tree. To drive it manually, turn that off and call
`start_battle()`.

Each fighter's `team` is its index in `fighter_scenes`, and it is set **before**
the fighter enters the tree, because it decides which layer the hurtboxes
register on.

`pair_fighters()` only runs once everyone is in the tree: linking opponents and
adjusting facing touches nodes that only exist after the fighter's `_ready`.

## Solver

`BattleManager` creates the `CollisionSolver` as a child and registers every
fighter in it. The solver resolves itself every physics frame, with
`process_physics_priority = 100` so it runs after all fighters have moved. See
[hitboxes.md](hitboxes.md).

## Input

`BattleManager` registers the mapping in the InputMap on startup
(`apply_input_bindings`) and gives each fighter the player index of its team:
team 0 plays on `p1_*`, team 1 on `p2_*`. See [input.md](input.md).

## Facing

Which way each fighter looks is the match's decision, not the fighter's: knowing
who faces whom is this class's responsibility.

```gdscript
for fighter in fighters:
	if fighter.can_turn():
		fighter.update_facing()
```

`can_turn()` is false during attacks, stun, hitstop and in the air. In practice:
**a started move never flips mid-attack**. A fighter crossing to the other side
during their own move keeps hitting where they started, which is the behaviour
the genre expects (and what makes crossups exist).

## API

| Member | Use |
|---|---|
| `fighters` | the match's fighters, in team order |
| `solver` | the match's `CollisionSolver` |
| `start_battle()` | clears and builds everything again |
| `spawn_fighter(scene, index)` | spawns a fighter on team `index` |
| `register_fighter(f)` | registers an already existing fighter |
| `pair_fighters()` | links opponents and sets the initial facing |
| `get_fighter(team)` | a team's fighter |
| `get_opponent_of(f)` | a fighter's opponent |
| `reset_positions()` | sends everyone back to spawn (round reset) |
| `clear_battle()` | removes every fighter |

**Signals**: `battle_started`, `fighter_spawned(fighter)`,
`fighter_died(fighter)`, `hit_resolved(hit)`.

## Test

```sh
godot --headless --path . --script tests/battle_smoke_test.gd
```

Covers spawn, teams, facing, the solver resolving a hit on its own, and the KO.

## Not implemented yet

- `RoundManager` and `Timer`: rounds, countdown, win conditions.
- A camera that follows the fighters, screen bounds and corner pushback.
