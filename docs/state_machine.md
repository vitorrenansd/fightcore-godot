# State Machine

Generic FSM used by the fighters. Every state is a child node of the state
machine, and frame counting is integer based: no `await`, no `Timer`, no time
in seconds.

## Classes

| Class | File | Role |
|---|---|---|
| `State` | `engine/state_machine/state.gd` | base of any state, counts `state_frame` |
| `StateMachine` | `engine/state_machine/state_machine.gd` | registers children and switches states |
| `FighterState` | `engine/character/fighter_state.gd` | base of fighter states, exposes `fighter` |
| `FighterStateMachine` | `engine/character/fighter_state_machine.gd` | the fighter's FSM |

The FSM is generic on purpose: `engine/state_machine/` does not know what a
fighter is. Coupling only happens in `FighterState`, which resolves `fighter`
from the scene `owner`.

## How it works

States are child nodes of the `StateMachine`. On `_ready` it indexes each child
by node name and connects everyone's `transitioned` signal:

```
StateMachine
├── Idle
├── Walk
├── Jump
├── Crouch
├── Block
└── Hitstun
```

The node name **is** the state identifier, so `transition_to(&"Hitstun")`
depends on the node being called `Hitstun`.

`Fighter._physics_process` calls `state_machine.physics_update(delta)`, which
forwards to the current state. The FSM has no `_process` of its own: the fighter
sets the pace, because during hitstop it needs to freeze the whole machine.

## Frame counting

```gdscript
func enter() -> void:
	state_frame = 0

func physics_update(_delta: float) -> void:
	state_frame += 1
```

`enter()` resets and every update increments **before** the logic, so on the
first update `state_frame == 1`. A state that lasts N frames leaves when
`state_frame >= N`.

## Switching states

From inside the state, through the signal:

```gdscript
if fighter.is_on_floor():
	transitioned.emit(&"Idle")
```

From outside, directly:

```gdscript
fighter.state_machine.transition_to(&"Block")
```

`transition_to` ignores unknown names and ignores a transition into the current
state — meaning **re-entering the same state does not call `enter()` again**.
Anything that needs a restart (every combo hit after the first) uses a method of
its own:

```gdscript
# Fighter._enter_hitstun
var state := state_machine.get_state(&"Hitstun") as FighterHitstunState
state.start_hitstun(hit.stun_frames)   # resets state_frame by hand
state_machine.transition_to(&"Hitstun")
```

`get_state()` exists exactly for parametrizing a state before entering it:
hitstun and blockstun take the duration of the move that just connected.

## Current states

| State | Behaviour |
|---|---|
| `Idle` | clears horizontal velocity |
| `Walk` | applies `direction` at walking speed |
| `Jump` | jumps on enter, returns to `Idle` on landing; also the airborne state |
| `Crouch` | clears horizontal velocity, counts as crouching for the guard |
| `Block` | blockstun only; blocking itself is holding back |
| `Hitstun` | locked for the move's frames; resets the fighter's combo on exit |
| `Attack` | runs an `AttackData`; returns to `Idle` when the move ends |
| `AirDash` | horizontal burst with gravity suspended |
| `Knockdown` | falls out of the combo, lands, lies there for `knockdown_frames` |
| `Wakeup` | gets up over `wakeup_frames`, invulnerable throughout |
| `KO` | knockout; disables the hurtboxes and never leaves on its own |

`AirDash` suspends gravity for its whole duration, which is what makes it read
as a straight line instead of a shallow jump. Attacks come out of it and keep
the momentum. It costs one of the fighter's air dashes.

`Jump` doubles as the airborne state. Entering it from the ground jumps;
entering it from the air — after an air attack, after an air dash — just means
"still falling", with no second impulse and no change to the arc.

`Knockdown` is where an air combo ends. Hitstun running out in the air always
goes here, never back to `Jump`: there is no air recovery, so handing control
back mid-air would let the victim leave a combo for free and would leave the
route with no ending at all. A grounded hit only goes here when the move is
authored with `causes_knockdown`.

The two halves of `Knockdown` are deliberately different. The fall stays
**vulnerable** — that is the juggle window, and juggle gravity is what decides
when it stops being extendable. From the frame the body touches the floor it
goes **invulnerable**, and stays that way through `Wakeup`, so a knockdown
cannot be looped into another one while the victim lies there.

Invincibility ends on the exact frame the fighter becomes actionable. That one
frame is the whole point of the wakeup: a meaty has to time its active frames
to still be running when the body comes back, instead of hitting someone who
cannot answer yet.

`Attack` does not count the move's frames: the `HitboxManager` does. The state
only waits for `is_attacking()` to become false. Entering it always goes through
`Fighter.perform_attack()`, which respects `can_act()` and handles the case of a
fighter that is already attacking — `setup()` restarts the move immediately,
which is how a cancel becomes the next move without passing through neutral.

## Adding a state

1. Create the script in `engine/character/states/`:

```gdscript
class_name FighterDashState
extends FighterState

func enter() -> void:
	super()
	fighter.velocity.x = fighter.stats.dash_speed * (1.0 if fighter.facing_right else -1.0)

func physics_update(delta: float) -> void:
	super(delta)
	if state_frame >= 12:
		transitioned.emit(&"Idle")
```

2. Add a node with that script under `StateMachine` in the fighter scene, named
   with the name used in transitions.

Always call `super()` in `enter()` and `super(delta)` in `physics_update()`:
that is what resets and increments `state_frame`.
