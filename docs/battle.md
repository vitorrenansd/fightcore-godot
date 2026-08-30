# Match

`BattleManager` (`engine/battle/battle_manager.gd`) owns the match: it spawns
the fighters, assigns teams, links the opponents and runs the
`CollisionSolver`. It is the only place in the engine that knows there are two
sides.

Rounds, timer and score do **not** live here — those belong to `RoundManager`,
[further down this page](#rounds).

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

## Spawning on the ground

In `spawn_positions`, `x` is the starting column and **`y` is measured from the
stage floor**: `0` puts the fighter on the ground, and a negative value starts
them that far above it.

The ground itself is never written down. `reset_positions()` casts each
fighter's own collision shape straight down the spawn column and stands them on
whatever it hits, so a taller character, a different floor height or a stage
with two levels all work with no number to keep in sync. A stage that changes
height cannot desync from a spawn constant that does not exist.

The cast runs more than once. `move_and_collide` binary-searches the motion
rather than solving it, so a single long cast stops short of the surface by
roughly its own length over 768 — a 4000px search leaves the fighter 10px in the
air. Each further cast starts where the last one stopped and reaches far less,
which closes the gap geometrically; `GROUND_SNAP_PASSES` is well past
convergence. The snap ends with a `move_and_slide()`, because a fighter is not
standing on anything until one says so, and without it `is_on_floor()` would
stay false through the whole intro.

`reset_positions()` is also called during `_ready`, where the physics space
cannot answer a query yet. When the cast finds nothing the fighters keep their
authored height and the snap is retried on the first physics frame — once, since
anything still failing has no floor under it at all.

## Solver

`BattleManager` creates the `CollisionSolver` as a child and registers every
fighter in it. The solver resolves itself every physics frame, with
`process_physics_priority = 100` so it runs after all fighters have moved. See
[hitboxes.md](hitboxes.md).

## Walls

`BattleManager` finds the stage's `StageBounds` at startup, hands them to the
`PushboxSolver` so the corner works, and feeds it every hit that lands. When a
wall breaks it is the match that moves both fighters into the next section,
deals the break damage and puts the victim on the floor — `StageBounds` reports
the break and never touches a fighter, because knowing that there are two sides
is this class's job and not the stage's.

Spawn columns are read relative to the current section, so a stage with five
screens needs no different spawn numbers than one with one. A match with no
bounds runs unwalled, which is what every hand built test gets. See
[stages.md](stages.md).

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
| `pushboxes` | the match's `PushboxSolver`, which also holds the walls |
| `stage_bounds` | the stage's walls, or null on an unwalled match |
| `start_battle()` | clears and builds everything again |
| `spawn_fighter(scene, index)` | spawns a fighter on team `index` |
| `register_fighter(f)` | registers an already existing fighter |
| `pair_fighters()` | links opponents and sets the initial facing |
| `get_fighter(team)` | a team's fighter |
| `get_opponent_of(f)` | a fighter's opponent |
| `reset_positions()` | sends everyone back to spawn, standing on the ground |
| `snap_fighters_to_ground()` | stands everyone on the floor; false if the space could not answer |
| `snap_to_ground(f)` | stands one fighter on the floor under their spawn column |
| `clear_battle()` | removes every fighter |

| `find_stage_bounds()` | walks the scene once for the stage's walls |

**Signals**: `battle_started`, `fighter_spawned(fighter)`,
`fighter_died(fighter)`, `hit_resolved(hit)`, `throw_broken(first, second)`,
`wall_broken(side, from_section, to_section)`.

## Rounds

`RoundManager` (`engine/battle/round_manager.gd`) sits one layer above and owns
the rules around the fight: rounds, clock and win conditions. Splitting the two
means a training room can run with no rounds at all, and a story mode can change
the win conditions without touching combat.

```gdscript
var rounds := RoundManager.new()
rounds.round_seconds = 99
rounds.rounds_to_win = 2
add_child(rounds)
```

`battle` can be left unset: the manager looks at its parent and then its
siblings for a `BattleManager`, so dropping the node next to one just works.

### Phases

| Phase | What happens |
|---|---|
| `INTRO` | fighters frozen, clock stopped, `intro_frames` long |
| `FIGHT` | fighters released, clock running |
| `ROUND_END` | pause after a KO or a timeout, `round_end_frames` long |
| `MATCH_END` | someone reached `rounds_to_win` |

Every phase is counted in frames, like everything else in the engine.

### Win conditions

| Reason | When |
|---|---|
| `KO` | one fighter ran out of health |
| `TIMEOUT` | clock ran out; the fighter with the higher health **fraction** wins |
| `DRAW` | double KO, or an exact health tie on timeout |

A KO is checked before the clock, so a knockout on the very last frame still
reads as a KO. A draw gives both sides the round, the usual double KO rule.

Health is compared as a fraction of the maximum so characters with different
health pools are judged fairly.

### Clock

`RoundTimer` (`engine/battle/timer.gd`) counts **frames**, not seconds. A clock
made of real seconds would drift away from a frame locked simulation and would
make a replay or a rollback land on a different countdown. It is named
`RoundTimer` because `Timer` is a native Godot class.

It also holds `FRAMES_PER_SECOND`, the rate the whole engine's frame data is
written for, and `verify_tick_rate()`, which `BattleManager` calls when a match
is built. See [archtecture.md](archtecture.md#engine-rules) for why the number
is asserted here instead of being pinned in `project.godot`.

### Reset between rounds

`BattleManager.reset_round()` calls `Fighter.reset_for_round()` on everyone —
health, combo, hitstop, velocity, the current attack and back to `Idle` — and
then `reset_positions()`. Leaving the `KO` state through its normal exit is what
turns the hurtboxes back on.

**Signals**: `round_started(round_number)`,
`round_ended(winner_team, reason)`, `match_ended(winner_team)`,
`phase_changed(phase)`. A winner of `RoundManager.NO_WINNER` means a draw.

## Test

```sh
godot --headless --path . --script tests/battle_smoke_test.gd
godot --headless --path . --script tests/round_smoke_test.gd
godot --headless --path . --script tests/training_scene_smoke_test.gd
```

The first covers spawn, teams, facing, the solver resolving a hit on its own,
and the KO. The second covers the intro freeze, a KO round, the reset between
rounds, a timeout decided by health and the end of the match. The third runs
the shipped `training.tscn` untouched, which is the only one that can catch a
stage the fighters no longer land on.

## Not implemented yet

- Round intro and result presentation: the phases exist, the animation does not.
- Freezing at round end stops a KO'd fighter mid-air instead of letting them
  land.
