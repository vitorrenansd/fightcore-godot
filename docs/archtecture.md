# Architecture

FightCore is a 2D fighting game engine built in Godot 4.7. This document covers
how the project is organized and which rules hold everywhere in the code.

## Conventions

**Everything in this repository is written in English** — identifiers,
comments, docstrings, these docs, the README, on-screen text and move names,
test output and commit messages. The project is public and takes outside
contributions, so a reader who does not speak the author's language has to be
able to use all of it.

**Commit messages are one line**, with a conventional-commit prefix and no
body: `feat(engine): add input buffer`, `fix(stage): fix wall collision`. A
change that needs explaining is explained here in `docs/`, where it can be
found later, rather than in a commit message nobody reads twice.

[CLAUDE.md](../CLAUDE.md) carries the same rules for anyone working on the
repository with an agent.

## Engine / content split

```
engine/     generic code, never knows which character is running
content/    characters and stages that use the engine
shared/     effects and resources used by more than one character
mods/       third party content
docs/       this documentation
tests/      headless tests
```

`engine/` never references anything under `content/`. A character is a `.tscn`
scene with the `Fighter` script plus a set of `.tres` resources — there is no
engine code specific to any character.

```
engine/
  battle/         match, rounds and timer
  character/      Fighter, data resources, concrete states
  collision/      hitbox, hurtbox, hit resolution
  debug/          box drawing for frame data tuning
  input/          input buffer, motions and mapping
  physics/        gravity, movement, knockback
  state_machine/  generic FSM
```

## Engine rules

**Fixed step simulation.** All fight logic runs in `_physics_process` at 60
ticks per second. No combat logic in `_process` and nothing that depends on the
video framerate.

The rate is not written in `project.godot`: Godot drops a project setting whose
value equals the engine default, and 60 *is* the default, so the line does not
survive the editor saving the project. It lives as
`RoundTimer.FRAMES_PER_SECOND` and `BattleManager` calls
`RoundTimer.verify_tick_rate()` when a match is built, which errors if the
project is running at anything else. A wrong rate never crashes — it just makes
every frame count in the engine mean the wrong amount of time — so it has to be
said out loud.

**Integer frame counting.** Startup, hitstun, blockstun and recovery are counted
as `int`, never in seconds and never with `await` or `Timer`. Every state
carries a `state_frame`.

**Authored data lives in `.tres`.** Frame data, stats and move lists are
resources, not script constants. Resources are shared between fighters, so they
**never** hold runtime state: the node holds it.

**No hit detection through signals.** `Area2D` overlaps arrive a frame late.
Hits are resolved with a direct PhysicsServer query on the same frame. See
[hitboxes.md](hitboxes.md).

**Flipping happens only on `Visuals`.** Turning a fighter around never uses
`scale.x = -1` on the root. The `Visuals` node flips its scale; boxes are
mirrored in code, by offset.

## Frame flow

```
Fighter._physics_process            (one per fighter)
  hitstop -> freeze and bail out
  hitbox_manager.advance()          advance the attack frame
  state_machine.physics_update()    current state logic
  knockback friction                only while stunned, only on the floor
  gravity (juggle included) + move_and_slide()
  on the floor -> land(): air options and juggle reset

CollisionSolver._physics_process    (process_physics_priority = 100)
  query active hitboxes against opposing hurtboxes
  build this frame's HitData
  apply them all at once
```

The solver runs at high physics priority so it acts after every fighter has
moved, regardless of their order in the scene.

## Checking the project

Nothing here needs the editor open:

```sh
# does everything compile? the grep is the check, see the test docstring
godot --headless --path . --script tests/script_load_test.gd 2>&1 \
    | grep -q "Failed to load script" && echo BROKEN

# does the game itself run? --quit-after, never `timeout`: Godot block-buffers
# stdout into a pipe, so killing it throws the whole error log away
godot --headless --path . --quit-after 300

# behaviour
godot --headless --path . --script tests/hitbox_smoke_test.gd
godot --headless --path . --script tests/battle_smoke_test.gd
godot --headless --path . --script tests/input_smoke_test.gd
godot --headless --path . --script tests/cancel_smoke_test.gd
godot --headless --path . --script tests/round_smoke_test.gd
godot --headless --path . --script tests/pushbox_smoke_test.gd
godot --headless --path . --script tests/air_smoke_test.gd
godot --headless --path . --script tests/juggle_smoke_test.gd
godot --headless --path . --script tests/knockdown_smoke_test.gd
godot --headless --path . --script tests/friction_smoke_test.gd

# the shipped scene, instantiated as the game launches it
godot --headless --path . --script tests/training_scene_smoke_test.gd
```

Every smoke test but the last one builds its match by hand, which checks the
engine and not the scene. `training_scene_smoke_test.gd` loads
`content/battle/training.tscn` untouched, so it is the only one that can catch
broken node wiring, a stage that no longer catches the fighters, or match
numbers changed by accident in the scene.

`--check-only --script <file>` reports parse errors per file, but it does not
catch everything: a `const` built from another class enum passes it and still
breaks in the editor. The load scan above is what catches those.

After adding a new `class_name`, run `--headless --path . --editor --quit` once
so the global class cache picks it up, otherwise standalone scripts will not
find the class.

## What is missing

[roadmap.md](roadmap.md) lists it, ordered by what each item unlocks.

## Current state

| System | Status |
|---|---|
| Generic FSM (`state_machine/`) | done — [state_machine.md](state_machine.md) |
| Fighter, stats and movement | done — [fighter_format.md](fighter_format.md) |
| Fighter states | idle, walk, jump, crouch, block, hitstun, attack, air dash, knockdown, wakeup, ko |
| Hitbox / hurtbox / HitData | done — [hitboxes.md](hitboxes.md) |
| Pushbox | done — [hitboxes.md](hitboxes.md) |
| `BattleManager` | done — [battle.md](battle.md) |
| Input, buffer and commands | done — [input.md](input.md) |
| Cancels and gatling routes | done — [cancels.md](cancels.md) |
| Juggle, knockdown and wakeup | done — [state_machine.md](state_machine.md) |
| Rounds, clock and win conditions | done — [battle.md](battle.md) |
| Playable training room | `content/battle/training.tscn` |
| `physics/knockback.gd` | done — friction rule, called by `Fighter` |
| `physics/gravity.gd`, `physics/movement.gd` | stub — both live in `Fighter` |
| `character/fighter_loader`, `fighter_manager` | stub |
| Walls, corner and camera | missing — the next slice, see [roadmap.md](roadmap.md) |
| Animation | stub — [animation.md](animation.md) |
| Modding | stub — [modding.md](modding.md) |
