# Input

FightCore's command reading: buffer, classic motions (quarter circles, dragon
punches) and customizable mapping.

## Button layout

Five buttons, Guilty Gear style:

| Button | Name | Role |
|---|---|---|
| P | Punch | fast, low damage |
| K | Kick | medium range |
| S | Slash | strong attack |
| HS | Heavy Slash | slow and heavy |
| D | Dust | universal overhead alone, throw with a direction |

`SYSTEM_1..3` stay reserved in the bitmask for system mechanics (burst, roman
cancel, macros). An unmapped button costs nothing and commits to no design.

D exists to give every character an overhead and a launcher without authoring
one move at a time.

**Specials come out through motions**, not dedicated buttons: `236S`, `623P`,
`214K`. That is what makes five buttons produce dozens of moves.

## Numpad notation

Directions use numpad notation, the genre standard everywhere:

```
7 8 9      up-back    up      up-forward
4 5 6      back       neutral forward
1 2 3      down-back  down    down-forward
```

The engine **stores the absolute direction** (4 is always screen left) and
converts to forward/back on read, using the facing. That is what keeps an input
recorded before a side switch meaningful.

| Motion | Sequence |
|---|---|
| quarter circle forward | `[2, 3, 6]` |
| quarter circle back | `[2, 1, 4]` |
| dragon punch | `[6, 2, 3]` |
| normal | `[]` |

## Pieces

| Class | File | Role |
|---|---|---|
| `FightInput` | `engine/input/fight_input.gd` | vocabulary: buttons, directions, SOCD |
| `InputBindings` | `engine/input/input_bindings.gd` | physical mapping, remappable |
| `InputDevice` | `engine/input/input_device.gd` | reads the InputMap and cleans SOCD |
| `InputHistory` | `engine/input/input_history.gd` | circular history, one record per frame |
| `CommandParser` | `engine/input/command_parser.gd` | matches motions against the history |
| `InputBuffer` | `engine/input/input_buffer.gd` | the fighter's component, ties it together |
| `CommandData` | `engine/character/command_data.gd` | input -> move |

## Buffer

Demanding the exact frame is unfair: the player presses a few frames before
being allowed to act and the move still has to come out. The default is
**8 frames**, inside the genre's 5 to 10 range — less punishes legitimate links,
more throws out moves the player never asked for.

Sampling continues during hitstop on purpose: that is exactly when the player is
setting up the rest of the combo.

A press that produced a move is marked as spent (`InputBuffer.consume()`), or
the same tap would fire again on the following frames.

## Motion recognition

The parser walks **backwards in time** from the frame the button went down: find
the press inside the buffer window, then the motion's last direction, then the
one before it, all the way to the first. It does not matter when the motion
started, only that it finished within `motion_window` (20 frames by default).

**A skipped diagonal does not break it** (`allow_skipped_diagonals`): almost
nobody hits the `3` in a `236`. A skipped cardinal does break it — otherwise
`26` would count as a quarter circle and specials would come out unasked.

A command with a motion has priority over one without, or `236S` would come out
as a plain `5S`.

## SOCD

Leverless controllers (hitbox) allow holding left and right at once, which
produces ambiguous input and is banned in tournament without handling.
`InputDevice` resolves it:

| Mode | Behaviour |
|---|---|
| `NEUTRAL` (default) | opposites cancel out |
| `LAST_WINS` | the most recently pressed direction wins |

Vertical always favours up: jumping beats crouching.

## Customizable mapping

Actions (`p1_up`, `p1_p`, `p2_hs`...) are created at runtime from
`InputBindings` instead of being fixed in `project.godot`, because remapping has
to work while the game runs and be saved per user
(`user://input_bindings.tres`).

Keyboard uses `physical_keycode`: a key is its physical position, so the
defaults behave the same on ABNT2, QWERTY and AZERTY.

```gdscript
var bindings := InputBindings.load_or_create()
bindings.set_event(0, &"p", 0, event)   # player 1, P button, slot 0
bindings.save()
```

Factory defaults:

| | P1 | P2 |
|---|---|---|
| Directions | WASD | arrows |
| P K S HS D | J K L U I | numpad 1 2 3 4 5 |
| Gamepad | device 0 | device 1 |
| Gamepad buttons | A=P B=K X=S Y=HS RB=D | same |

The analog stick uses a high deadzone (0.5) on purpose: without it it behaves as
a continuous axis and produces intermediate directions, which turn into false
motions.

`Input.use_accumulated_input` is disabled when the bindings are applied — Godot
would merge events from the same frame and sub-frame link timing would be lost.

## A character's commands

`CommandData` lives in `FighterData.commands`. Each one binds an input to an
`AttackData`:

```gdscript
command.motion = [2, 3, 6]
command.button = FightInput.Buttons.S
command.stance = CommandData.Stance.ANY    # ANY, STAND, CROUCH, AIR
command.hold_direction = 6                 # optional: makes 6P its own command
```

`button` is a bitmask and not an enum on purpose: a two-button macro (throw,
burst) needs to set more than one.

Training dummy commands: `5P`, `5K`, `2K`, `5S`, `5HS`, `5D`, `236S`, and the
air normals `j.P`, `j.K`, `j.S`, `j.HS`.

Stance is what picks between them: the same P button gives `5P` standing and
`j.P` in the air. A `Stance.ANY` command never fires airborne — ground moves
staying on the ground is the default, not something each move opts out of.

## Air options

Both extra air actions are spent until the fighter lands, which is what stops
anyone from staying airborne forever.

| Action | Input | Cost |
|---|---|---|
| Double jump | up, **released and pressed again** | one air jump |
| Air dash | double tap forward or back in the air | one air dash |

The release matters: without it the same press that started the jump would spend
the air jump on the very next frame.

The dash is matched on the **horizontal component** and not on an exact
direction, because in the air the player is usually holding up-forward and taps
through 9 and 5, never through a clean 6.

Counts and speeds are per character, in `FighterStats`: `air_jumps`,
`air_jump_velocity`, `air_dashes`, `air_dash_speed`, `air_dash_frames`.

## Guarding

Blocking is not a button: **holding back defends**, as in every 2D game in the
genre. `Fighter.is_blocking()` looks at the input, not at the state. Holding
down-back blocks lows; standing blocks overheads.

## Training room

`content/battle/training.tscn` is the project's main scene. It shows health,
state, attack frame, the direction being read and hitstop for both sides; **F1**
toggles the hitbox and hurtbox overlay.

## Test

```sh
godot --headless --path . --script tests/input_smoke_test.gd
```

Simulates input with `Input.action_press` and covers SOCD, stance, the buffer,
motions, skipped diagonals and the move connecting.

## Not implemented yet

- Charge motions (`[4]` held for 40 frames, then `6`).
- Two-button commands in practice (the bitmask already accepts them).
- A remapping screen: the API exists, the UI does not.
