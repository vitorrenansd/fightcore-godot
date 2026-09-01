# Roadmap

What is missing, ordered by what it unlocks rather than by area. Every item
lists the file that already exists as a stub, when there is one.

For what is already built, see [archtecture.md](archtecture.md).

## Just closed: the stage has a corner

A stage is a ring of one screen sections now, and the wall between two of them
has health. Cornering someone means the whole pushback goes into them instead of
half of it; clean hits wear the wall down; breaking it drops both fighters into
the next screen with the victim on the floor. Leave them alone and the wall
comes back in about a second, so the corner has to be held rather than reached.

The camera came with it and not after it: what the camera can frame is what
decides how wide a section is, so building them apart would have meant building
the same boundary twice.

The ends of the ring join up, which is the one thing the shape buys — no section
is a dead end, and the count is a number in a resource rather than a shape in a
scene, so a stage can have two screens or eleven.

Details: [stages.md](stages.md).

## Before that: blocking is no longer free

`6D` and `4D` throw, every character has them without authoring them, and two
throws reaching each other break instead of resolving. Before this the correct
answer to any pressure was to hold back and wait: nothing in the game could
open a guard, so the mid-range game came down to whoever got bored first.

The throw is a guess with a real cost on both sides — 24 frames of recovery for
missing it, a 10 frame window for reading it — which is what turns holding back
into a decision instead of a default. Landing one pops the opponent up and gives
the fighter their turn back, so it starts a combo instead of ending the exchange.

`AttackData.recovery_on_hit` came out of it: a throw needs a punishable whiff and
a hit that hands the fighter back, and one recovery number cannot be both. It is
generic, and no move other than the throws uses it yet.

The dust gave the launch up in the process. It had been carrying two jobs — the
universal overhead and the only way into an air combo — and once the throw took
the second one, `5D` was left doing the job it is named for: it beats a crouching
guard, it is blocked standing, and nobody moves.

Details: [throws.md](throws.md).

## And before that: the combat loop got an ending

Juggle gravity, knockdown/wakeup and knockback friction landed together, and
they are one thing rather than three. Before them the air route built by the
previous commits — launcher, jump cancel, air normal, air dash — had no
terminator: hitstun running out in the air handed control straight back, so the
same route repeated and damage scaling only made it cheap.

Now every airborne hit raises the victim's gravity until the route stops
reaching, hitstun ending in the air drops them into a knockdown, and getting up
has its own timing with the invincibility that ends exactly when the fighter
becomes actionable. That is the `Advantage → Repeat` half of the genre core
loop, which simply did not exist before.

Details: [state_machine.md](state_machine.md) for the states,
[fighter_format.md](fighter_format.md) for the authored fields.

## The next slice: okizeme, and the fight being fair

**Agreed as the next piece of work.** The corner now exists, and the corner is
exactly where the imbalance shows: a knockdown there is the strongest position
in the game, and the fighter getting up has no say in it at all.

**Wakeup options.** No wakeup roll, no reversal, no delayed wakeup. The attacker
sets up freely and the defender waits for it. The invincibility window is
already in `Wakeup` for a reversal to come out of, and the throw is already the
answer to a guard, so the pieces the option select needs are in place — what is
missing is a choice for the person on the floor.
→ `engine/character/states/wakeup.gd`

**Ground dash and backdash.** The air dash exists, the ground one does not.
`FighterStats.dash_speed` is there and unused. A backdash with invincibility
frames is a defensive option the game currently has none of, and it is the one
that makes the corner a place you can try to leave.

## Then: the moveset is thin

**Air throws, and a reaction of their own.** The ground throw is in. A thrown
opponent still goes through plain hitstun into a knockdown, because there is no
animation to hang a real throw reaction on yet, and nobody can be grabbed out
of the air.
→ `engine/system/`, [throws.md](throws.md)

**Super moves and meter.** `AttackData.CancelType.SUPER` and
`FighterStats.max_meter` both exist and neither is used. Needs meter gain on
hit, on block and on taking damage, a spend rule, and the cinematic freeze.

**Charge motions.** `[4]` held for 40 frames then `6`. The parser handles
sequences but not held time.
→ `engine/input/command_parser.gd`

**Proximity guard.** Blocking works, but there is no automatic guard when a
hitbox comes close.

## Then: it does not look like a game

**Animation.** Fighters are coloured polygons. The plan is `AnimationMixer`
with `ADVANCE_MANUAL`, driven by the same integer frame counter as the frame
data, so a sprite never drifts from its hitbox.
→ [animation.md](animation.md) (empty), `FighterData.sprite_frames` unused

**HUD.** The training room prints debug text. A real match needs health bars,
round pips, the timer and combo counters.

**Round presentation.** The phases exist (`INTRO`, `ROUND_END`) but nothing is
drawn during them, and freezing at round end stops a KO'd fighter mid-air
instead of letting them land.

**Sound.** Nothing at all: hit, block, whiff, jump, voice.

**Character select and match flow.** No screens, no roster, no way to pick a
fighter. `fighter_loader.gd` and `fighter_manager.gd` are stubs waiting for it.

## Later: the parts that need the rest to exist first

**Modding.** The format is already data driven and documented, but nothing
loads content from `mods/`. Needs a manifest, a load order and validation of
untrusted `.tres`.
→ [modding.md](modding.md) (empty), `mods/`

**Rollback netcode.** The simulation is already frame locked and deterministic,
which is the hard prerequisite. What is missing is serialising the whole match
state into a buffer, restoring it, and re-simulating. Every system that keeps
runtime state — `HitboxManager`, `InputBuffer`, `RoundManager` — has to be part
of that snapshot.

**Training mode.** Dummy behaviour settings, frame data readout, hitbox display
toggles and input display. Half of it already exists in the debug renderer.

**Balance tooling.** Simulating matchups instead of guessing at numbers.

## Known small rough edges

- A fighter frozen at round end stops mid-air instead of landing.
- `engine/physics/gravity.gd` and `movement.gd` are stubs; gravity currently
  lives in `Fighter`. `knockback.gd` is real now, the other two are not.
- There is no air recovery, so every airborne hit ends in a knockdown. A burst
  or an air tech would be the counterplay.
- A knocked down fighter is still hittable on the single frame they touch the
  floor: `is_on_floor()` reflects the previous `move_and_slide()`, so `Knockdown`
  turns the body off one frame after the landing the solver already saw. Left
  as is on purpose — that frame reads as the tail of the fall, not as okizeme.
- The pushbox is a width only. A proper one would have a height too, so a
  crouching fighter takes less space.
- No input display, so verifying what the buffer read means reading the HUD
  number.
