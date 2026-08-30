# Stages, walls and the camera

A stage is a **ring of sections**. Each section is one screen wide, walled on
both sides, and the only way out of one is to break a wall and end up in the
next.

Before this the stage was a floor and nothing else, so a fighter could be pushed
sideways forever and pushback never ran out. The corner is what makes pressure
mean something: it is the one place where giving ground stops being an option.

## Sections

```
        section 1              section 2              section 3
   |==================|====================|====================|
   ^                  ^                    ^                    ^
   wall            wall                 wall                 wall
```

The count is a number in `StageData`, not a shape in a scene. Two sections work,
so do eleven. Sections are laid out left to right with the middle of the stage
at x 0, so the section a round starts in sits exactly where a single screen
stage would have been and nothing about spawning changes.

**The ends join up.** Breaking the right wall of the last section arrives in the
first, and breaking the left wall of the first arrives in the last. There is no
final section to be stuck in, and no section that stops mattering once you have
passed it.

**The wall does not stay broken.** The section you arrive in has two whole walls
of its own. A ring whose walls stayed down would turn into one open field after
enough breaks, and the corner would stop existing halfway through a match.

## The corner

`PushboxSolver` resolves the walls and the fighter separation together, because
they are one constraint and not two: solved apart, the wall clamp undoes the
separation or the separation pushes someone through the wall, depending on which
ran last.

Normally two overlapping fighters split the separation evenly. A fighter with
their back to the wall has no ground to give, so **the whole push goes into the
opponent instead of half of it**. That is the entire reason cornering someone is
worth doing: the same overlap that used to move both of you now only moves them.

The per frame cap still holds on both sides, so landing fully overlapped in a
corner separates over a few frames rather than teleporting anyone.

Airborne fighters are kept inside the walls too. They still pass through each
other, which is what a crossup is.

## Wall damage

A wall has health the way a fighter does.

| Event | Effect on the wall |
|---|---|
| clean hit on a cornered opponent | takes the damage the hit dealt |
| the same hit blocked | nothing |
| a hit whose knockback points away from the wall | nothing |
| nothing for `wall_regen_delay` frames | starts coming back |

**Only clean hits count.** A wall that fell to chip would make the corner a
place you leave by holding back, and the guard already answers a blocked hit.

**The amount is the damage the hit actually dealt**, scaling included. A long
combo wears the wall the same way it wears the fighter: less per hit as it goes
on. Nothing is authored per move — a heavy normal hurts the wall more than a jab
because it hurts the fighter more.

**Cornered means cornered.** The victim has to be against the wall *and* be
knocked toward it. A hit that sends someone out of the corner drives nothing
into anything.

## Regen

Leaving someone alone in the corner undoes the work of putting them there. After
`wall_regen_delay` frames without damage the wall refills at
`wall_regen_per_frame`, reaching full in about a second.

The delay is what separates a dropped combo from a blockstring: the gaps inside
pressure are shorter than it, so keeping someone pinned keeps the wall down,
while letting them out gives it back.

## The break

The frame a wall reaches zero:

1. Both fighters come out in the next section — the attacker at
   `wall_break_entry` from the edge they came through, the victim
   `wall_break_separation` ahead of them, the gap a round starts at.
2. The victim takes `wall_break_damage`, which goes through the same KO path as
   a hit. Dying to the stage is not a special case anywhere downstream.
3. The victim goes into `Knockdown`, so the combo ends on the spot and the new
   section opens on a wakeup instead of on the same pressure carrying over.
4. The new section's walls are full.

`BattleManager` does all of that. `StageBounds` reports the break and never
touches a fighter: knowing that there are two sides is the match's job.

## The camera

`FightCamera` sits still in the middle of the section and cuts to the next one
when a wall breaks. That is the whole of it: it does not follow anyone and it
runs no per frame work.

**The zoom never changes.** A section is exactly one screen wide and the walls
keep both fighters inside it, so there is nothing for a zoom to react to — the
pair cannot get further apart than the view already shows. A camera that pulled
back with distance would be answering a question the walls already answered, and
it would make the fighters change size for no reason a player can act on.

`FightCamera.fixed_zoom` and `StageData.section_width` are one setting in two
places: at that zoom the view is exactly one section wide, so the walls land on
the edges of the screen. Change one without the other and the corner stops
lining up with what you can see. At the project's 1152 wide viewport, a zoom of
0.9 frames 1280 units, which is the section width.

A section change is a **cut**. Both fighters were placed rather than walked over,
so easing into it would be a shot of the stage sliding past.

## Authored numbers

`StageData`, one resource per stage. `content/stages/empty_stage/stage_data.tres`
is the one the training room uses.

| Field | Value | Why |
|---|---|---|
| `section_count` | 3 | |
| `section_width` | 1280 | exactly what the camera frames, and never more |
| `start_section` | -1 | the middle one, equal walls either side |
| `wall_health` | 3000 | a little over one full corner combo |
| `wall_regen_delay` | 40 | longer than the gaps inside a blockstring |
| `wall_regen_per_frame` | 50 | empty to full in a second |
| `wall_break_damage` | 800 | about one heavy normal |
| `wall_break_entry` | 200 | how far in the attacker lands |
| `wall_break_separation` | 280 | the distance a round starts at |

`FightCamera.fixed_zoom` is 0.9 and belongs with `section_width` above, even
though it is authored on the camera node and not in the resource.

## Placeholder art

There is none yet, so `content/stages/empty_stage/stage.gd` draws the stage from
the same data: a rectangle per section with its number sitting just above head
height, a bar at each edge for the wall, and a seam where two sections meet. The
two walls of the section being fought in drain from grey to red as they take
damage; the rest are drawn faint, because they are scenery until the fight
reaches them.

The training room announces a break — `WALL BREAK    screen 2 -> 3` — for two
seconds under the round banner, counted in frames like everything else. It reads
`BattleManager.wall_broken`, so it is a HUD reaction and not something the stage
knows about.

Built in code and not authored as nodes on purpose: the section count is a
number, and a stage with five screens must not need five copies of anything.
Once there is art a section becomes a scene, and that script is what it replaces.

The floor is one body under every section. Fighters find the ground by casting
their own shape down it — see [battle.md](battle.md) — so no height is written
anywhere and a stage with a different floor works with no change.

## Pieces

| Class | File | Role |
|---|---|---|
| `StageData` | `engine/stage/stage_data.gd` | authored numbers, one per stage |
| `StageBounds` | `engine/stage/stage_bounds.gd` | current section, wall health, regen, the break |
| `FightCamera` | `engine/camera/fight_camera.gd` | sits on the section, cuts on a break |
| `PushboxSolver` | `engine/collision/pushbox_solver.gd` | the corner |
| `BattleManager` | `engine/battle/battle_manager.gd` | feeds hits in, moves everyone through |

`StageBounds.find_in()` walks the scene once at startup, and both the match and
the camera use it: the bounds live inside the stage scene, which is a sibling of
neither's parent, so the parent-then-siblings lookup used elsewhere in the engine
is one level too shallow for them. A match with no bounds runs unwalled, which is
what every hand built test gets.

## Test

```sh
godot --headless --path . --script tests/wall_smoke_test.gd
```

Covers the ring and its wraparound, the clamp, the corner push, a clean hit
wearing the wall down against a blocked one that does not, the regen delay, the
break and where it puts everyone, and the round reset. Section counts other than
three are checked there too, so the count staying a number is under test rather
than assumed.

```sh
godot --headless --path . --script tests/training_scene_smoke_test.gd
```

The camera and the break notice are checked there instead, because both only
exist once the real scene is running: it spreads the fighters to opposite walls
and asserts that neither the zoom nor the camera moved.

## Not implemented yet

- Sections with different floors or heights. The ground is found by casting, so
  nothing in the engine assumes they are flat — but nothing has tried it either.
- A wall break animation, or any reaction of its own. The victim goes through
  plain hitstun into a knockdown.
- Wall damage from a blocked hit at a reduced rate, which is the obvious knob to
  turn if the corner ends up too easy to sit in.
- Stage specific hazards, moving stages, and anything else a section could hold
  besides a floor.
- A window whose aspect is wider than the project's shows a little past the
  walls, because the zoom is fixed and the stretch mode expands. It is a
  presentation call to make when there is art to letterbox against.
