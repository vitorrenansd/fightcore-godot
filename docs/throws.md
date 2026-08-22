# Throws

The grab every character has: `6D` forward, `4D` back. It is the answer to
someone who will not stop blocking, and the first mechanic the engine ships as
content of its own rather than leaving to each character.

## Why it is a system move

Blocking costs nothing. Without a way through a guard, the correct play against
pressure is to hold back and wait, and the whole mid-range game collapses into
whoever gets bored first. The throw is what makes standing still a choice
instead of a default.

That only works if **every** character has it. A cast where some fighters can
open a guard and others cannot is not a balance question, it is two different
games. So the throw is not authored per character: it lives in `engine/system/`
and `Fighter` merges it into every fighter's command list on `_ready`.

```
engine/system/
├── system_moves.gd       SystemMoves: the list every fighter gets
├── system_moves.tres     the shared instance
├── throw_forward.tres    AttackData, 6D
└── throw_back.tres       AttackData, 4D
```

It is still authored data, not script constants — the engine rule that frame
data lives in `.tres` holds here exactly as it does for a character's moves.
What makes these system moves is where they live, not how they are written.

A character can still author a `6D` of their own. It wins on
`CommandData.get_effective_priority()`, the same rule that makes `236S` beat
`5S`, and not on the order of the merge.

## Input

| Command | Input | Effect |
|---|---|---|
| `6D` | forward + D | pops the opponent up in front of the attacker |
| `4D` | back + D | trades columns with the opponent, then pops them up |
| `5D` | D alone | still the dust, unchanged |

The direction is read in fighter space, so `6` is forward on either side. A held
direction adds to a command's effective priority, one rung below a motion —
without that `5D` and `6D` would tie on the same button and the list order would
decide which came out.

## What a throw catches

`Fighter.can_be_thrown()` is a much shorter list than `can_be_hit()`. A grab
only catches an opponent who is **grounded and in control**:

| Situation | Result |
|---|---|
| standing, walking, crouching | thrown |
| blocking | thrown — the guard does nothing |
| airborne | whiffs |
| in hitstun or blockstun | whiffs |
| knocked down or waking up | whiffs |
| recovering from a throw break | whiffs |

The guard line is the point of the move. The rest of the list is what keeps it
from becoming something else: a throw that connected during hitstun would be a
combo ender, and a throw that caught an airborne opponent would be an anti-air
that beats every jump for free.

A whiffed grab is a real whiff. It has 24 frames of recovery and nothing
cancels out of it, so going for one and missing is the worst thing on the
character's list — which is what makes the guess a guess.

## Landing one

A throw that connects does not owe those 24 frames. It authors
`recovery_on_hit = 12`, so the fighter is handed back while the opponent is
still in the air:

```
throw connects                    ─┐
attacker free                      │  25 frames after contact
opponent airborne and vulnerable   │  13 to 54 frames after contact
opponent out of hitstun            │  82 frames after contact
```

That leaves roughly 20 frames of airborne opponent to work with, which is one
or two hits before juggle gravity closes the route — `6D > 5P > 5K` lands, the
`5S` after it catches them on the way down, and the fourth does not reach. Off
the ground it is about 2100 damage for a correct read.

Splitting whiff recovery from hit recovery is what makes both halves possible.
With one number, a throw is either safe to throw out or worthless when it
lands. `recovery_on_hit` is generic and any move can use it; the throw is just
the case that could not exist without it.

## The break

Both players reaching for a throw at the same time is not something to resolve
in someone's favour. It resets.

Starting a throw opens a **10 frame tech window** on the fighter. A grab that
reaches someone whose window is still open **breaks**: neither throw happens,
both fighters are pushed apart by the same amount and both are locked out for
the same 20 frames.

```
p1 presses D+6      f0 ─────────────────── window open ──────────── f9
p1's grab active                     f5 f6 f7
p2 presses D+6                 f-4 … f5           → break
p2 presses D+6                 f6 …               → too late, p2 is thrown
```

Ten frames is a workable window: wide enough that going for the break is a read
a player can make, narrow enough that it still has to be one. It is symmetric —
whoever presses first, the other has until five frames after that press.

The break is deliberately even on both sides:

- The push is the same number on both fighters and is **not** divided by
  `weight`, unlike every other knockback in the engine. A heavier character
  coming out of it closer would turn the break itself into something worth
  fishing for.
- The lockout is the same count on both. If one side recovered first, breaking
  a throw would be a way to win the exchange, and the reason a break exists is
  that nobody won it.

Only a throw breaks a throw. A grab and a strike landing on the same frame is
an ordinary trade, which the solver already allows.

## How it resolves

Throws use the same pipeline as everything else: the throwbox is a `Hitbox` on
the `AttackData`, queried against the opponent's hurtbox layer by
`CollisionSolver` — see [hitboxes.md](hitboxes.md). Three things are different,
all of them in `CollisionSolver._resolve`:

1. A throw against someone whose tech window is open records a break instead of
   building a `HitData`.
2. A throw against someone who cannot be thrown returns nothing at all.
3. Neither outcome registers a hit, so a grab that whiffed on its first active
   frame is still free to catch the same opponent on the next one.

Breaks are collected during the frame and applied after every hit, the same way
hits are collected before any of them is applied. By the time a break is
applied both sides already know about each other, so the two fighters can never
disagree about whether the exchange happened.

Because the throwbox is an ordinary hitbox, the debug overlay draws it — in
purple rather than red, since it obeys none of the rules a red box does.

## Authored numbers

Both throws, in `engine/system/`:

| | |
|---|---|
| startup / active / recovery | 5 / 3 / 24 |
| recovery on hit | 12 |
| grab box | 24 × 76 at `(21, -8)`, reaching 56px between origins |
| damage | 1000 |
| guard | `UNBLOCKABLE` |
| hitstun | 32, `launcher`, `causes_knockdown` |
| knockback | `(80, -400)` forward, `(-80, -400)` back |
| hitstop | 12 forward, 26 back |
| tech window | 10 frames |
| break lockout | 20 frames |
| break pushback | 300 px/s each side |
| cancels | none, in or out |

The horizontal knockback is deliberately small. A throw that sends the opponent
across the screen cannot be followed up by anyone without a ground dash, so the
pop-up is nearly vertical and the fighter stays in range of their own buttons.

**Range.** The grab box reaches 33px from the fighter's origin, so it connects
up to 56px between origins. Pushboxes hold two standing fighters 46px apart,
which leaves ten pixels of air: the throw is a point-blank tool and there is no
grabbing anyone from a step away. Holding back is enough to walk out of it,
which is a real answer and not a bug — down-back guards without giving ground,
and that is the situation the throw is for.

**The side switch.** `4D` swaps the two fighters' columns outright, in code,
and turns both around. It is not done with knockback: carrying someone past the
attacker fast enough to get there would send them far enough that nothing can
follow up, and a back throw that ends the exchange is the one thing it is not.
The swap is instant — no interpolation, on purpose — so `reset_physics_interpolation()`
goes with it, or both fighters smear across the screen.

What makes it readable is the freeze after it. The back throw authors 26 frames
of hitstop against the forward throw's 12, so both fighters are held in place
long enough for the player to see that the sides changed. Hitstop is symmetric,
so the longer hold costs the attacker nothing: the follow-up window is the same
on both throws. That hold is also where a throw animation goes once there is
one to play.

The throw group on `AttackData` is generic, so a character-specific throw is
authored the same way: set `is_throw`, and the rest of the rules follow.

## State

A broken throw puts both fighters in `ThrowBreak`
(`engine/character/states/throw_break.gd`), which counts the lockout and bleeds
the push off with the fighter's own `knockback_friction`. It reads as a stun to
the rest of the engine — no commands, no guard, no turning around — but unlike
blockstun it does not let the fighter block, because a break is both sides
losing their turn.

A throw that lands is ordinary hitstun carrying `causes_knockdown`, so the
combo ends on the floor and the victim gets their wakeup — with or without a
follow-up. `FighterHitstunState` accumulates the flag rather than replacing it:
a jab picked up after the throw cannot cancel what the throw decided, or
`6D > 5P` would hand the opponent back standing as if nothing had happened.

There is no separate thrown state, and no throw-specific animation to hang one
on yet.

## Test

```sh
godot --headless --path . --script tests/throw_smoke_test.gd
```

Ten phases: the throw reaching a character that never authored it, the tech
window lasting exactly its count, the grab going through a guard, whiffing on an
airborne opponent and on a combo victim, the break and its symmetry, a whiffed
throw being punished by a throw once the window is closed, the back throw's
side switch and the hold that follows it, `6D` / `4D` / `5D` coming out of the
same button, and a follow-up connecting while the thrown opponent is still off
the ground — after which they still end up on the floor.

## Not implemented yet

- Air throws.
- A throw-specific reaction, and the animation that would justify one.
- Character-specific throws. The data supports them; no character has one.
- Command throws — a throw on a motion input, with the range and damage that
  usually come with one.
