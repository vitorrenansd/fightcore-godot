# Cancels

A cancel is interrupting a move that is already running to start another one.
It is what turns isolated hits into combos, and it is the difference between a
fighting game and a game where you take turns swinging.

## The rule

A cancel is only allowed when three things hold at the same time:

1. The current move is **past its cancel window start** — the first active
   frame by default. You cannot cancel out of startup, which is what keeps
   commitment in the game.
2. The move **touched the opponent**, on hit or on block. A whiff cancels
   nothing unless the move sets `can_whiff_cancel`.
3. The target move is **allowed by the current move's routes**.

Everything is authored on `AttackData` and evaluated by
`Fighter.can_start_attack()`.

## Routes

Three mechanisms, from cheapest to most specific:

**Gatling ladder** (`cancel_level`) — a normal only cancels into a normal with a
**strictly higher** level. Following the button order P=0, K=1, S=2, HS=3, D=4
gives the whole chain for free:

```
5P -> 5K -> 5S -> 5HS -> 5D
```

The "strictly higher" part is what stops a move from chaining into itself
forever.

**Move classes** (`cancel_type` and `cancel_into_types`) — every move is a
`NORMAL`, a `SPECIAL` or a `SUPER`. `cancel_into_types` is a flag set of the
classes this move may cancel into. Normals allow `Normal | Special | Super`;
specials allow `Super` only, so a special never falls back into a normal.

**Explicit routes** (`cancel_into`) — a list of attack ids that bypasses both
rules above, for the exceptions every character ends up needing (a low that
chains into another low of the same level, a move that links back into itself).

```gdscript
attack.cancel_type = AttackData.CancelType.NORMAL
attack.cancel_level = 1                       # a K
attack.cancel_into_types = 7                  # normal, special and super
attack.cancel_into = [&"2D"]                  # plus this specific exception
```

## Timing

```
frame:   0  1  2  3 | 4  5  6 | 7 ... 14
         startup     | active  | recovery
                     ^
                     cancel window opens (cancel_window_start = -1)
```

`cancel_window_start = -1` means the first active frame. Setting it explicitly
moves the window: a later value makes the move harder to combo from, an earlier
one is how a move becomes cancellable during startup.

The window stays open through the whole recovery. A move cancelled early ends
immediately: the new attack restarts the counter from frame 0 and clears the
hit record, so it can connect again.

**Hitstop delays the cancel, it does not eat it.** Both fighters freeze for a
few frames on impact, and the input buffer keeps sampling through the freeze, so
a button pressed during hitstop comes out the moment it ends. That is why the
buffer keeps running while frozen — see [input.md](input.md).

## Damage scaling

Cancelling does not bypass scaling: every hit in the combo removes 10% of the
damage of the next one. `5P` into `5K` deals 300 + 405 instead of 300 + 450.
See [hitboxes.md](hitboxes.md).

## Implementation

| Piece | Role |
|---|---|
| `AttackData.can_cancel_into(other)` | route rules |
| `AttackData.get_cancel_window_start()` | first cancellable frame |
| `HitboxManager.has_connected` | whether the move touched anyone |
| `HitboxManager.is_in_cancel_window()` | timing and contact |
| `Fighter.can_start_attack(attack)` | the whole decision |
| `FighterAttackState.physics_update()` | polls the input mid-move |

`Fighter.perform_attack(attack, force)` skips the rules when `force` is true,
for scripted moves and tests.

The attack state polling the input is what makes cancels exist at all: without
it the command would only be read after recovery ended.

## Training dummy

| Move | Level | Cancels into |
|---|---|---|
| 5P | 0 | 5K, 2K, 5S, 5HS, 5D, 236S |
| 5K / 2K | 1 | 5S, 5HS, 5D, 236S |
| 5S | 2 | 5HS, 5D, 236S |
| 5HS | 3 | 5D, 236S |
| 5D | 4 | 236S |
| 236S | special | supers only (none exist yet) |
| j.P | 0 | j.K, j.S, j.HS |
| j.K | 1 | j.S, j.HS |
| j.S | 2 | j.HS |
| j.HS | 3 | — |

Air moves use the same ladder, so `5D` launching into a jump and then
`j.P > j.K > j.S` is a real combo route.

## Test

```sh
godot --headless --path . --script tests/cancel_smoke_test.gd
```

Covers the ladder, the special cancel, the whiff block and the cancel window.

## Not implemented yet

- Jump cancel and dash cancel.
- Roman cancel style mechanics, which would cancel *anything* at a meter cost.
- Cancel only on counter hit, or only in the corner.
- Super moves: the class exists in the enum, nothing uses it yet.
