# Roadmap

What is missing, ordered by what it unlocks rather than by area. Every item
lists the file that already exists as a stub, when there is one.

For what is already built, see [archtecture.md](archtecture.md).

## Next: the fight is not fair yet

These are the gaps a player runs into within a minute of playing.

**Walls and the corner.** The stage is only a floor, so a fighter can be pushed
out of the screen forever. Screen bounds turn the corner into a real place: it
is where pushback stops working, where mixups get scary, and where half the
game's tension lives.
→ `engine/battle/battle_manager.gd`, stage scene

**Camera.** One static camera that does not follow anyone. It needs to frame
both fighters, zoom with the distance between them and clamp to the stage
bounds — which is also what defines where the corner is.

**Okizeme options.** Knockdown and wakeup exist, but the fighter getting up has
no say in it: no wakeup roll, no reversal, no delayed wakeup. Right now the
attacker sets up freely and the defender only waits. The invincibility window
is already there for a reversal to come out of.
→ `engine/character/states/wakeup.gd`

## Then: the moveset is thin

**Throws.** The `D` button was designed as dust alone and throw with a
direction, but only dust exists. Throws need their own box type, their own
whiff animation, and a tech window — they are the answer to a turtling
opponent.
→ `engine/collision/`, `CollisionLayers` already reserves the layer

**Ground dash and backdash.** The air dash exists but the ground one does not.
`FighterStats.dash_speed` is already there and unused. A backdash with
invincibility frames is a defensive option the game currently has none of.

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
- The pushbox is a width only. A proper one would have a height too, so a
  crouching fighter takes less space.
- No input display, so verifying what the buffer read means reading the HUD
  number.
