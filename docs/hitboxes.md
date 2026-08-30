# Hitboxes, Hurtboxes and HitData

FightCore's hit detection and resolution system.

## Core idea

**A hitbox is data, a hurtbox is a volume.**

Only the hurtbox exists in the physics server. A hitbox never becomes a scene
node: on the frame it is active, `CollisionSolver` turns it into a
`PhysicsDirectSpaceState2D.intersect_shape` query against the opposing team's
hurtbox layer.

`Area2D` signals (`area_entered`, `get_overlapping_areas`) are used nowhere in
resolution: area overlap only updates once per physics frame and arrives too
late, which breaks trades and same-frame exchanges.

## Pieces

| Class | File | What it is |
|---|---|---|
| `Hitbox` | `engine/collision/hitbox.gd` | immutable `Resource`: shape, offset, frame window, `hit_group` |
| `Hurtbox` | `engine/collision/hurtbox.gd` | passive `Area2D` on the team layer, `monitoring = false` |
| `AttackData` | `engine/character/attack_data.gd` | frame data and hit properties of a move |
| `HitData` | `engine/collision/hit_data.gd` | fully resolved result of one hit |
| `HitboxManager` | `engine/collision/hitbox_manager.gd` | runtime state of a fighter's boxes |
| `CollisionSolver` | `engine/collision/collision_solver.gd` | queries and applies the frame's hits |
| `CollisionLayers` | `engine/collision/collision_layer.gd` | layer and mask map |

`AttackData` and `Hitbox` are shared by every fighter using the same move, so
they **never** hold runtime state. The current attack frame and the record of
who has already been hit live in the `HitboxManager`.

## Layers

| Bit | Layer | Use |
|---|---|---|
| 1 | `WORLD` | stage floor and walls |
| 2 | `PUSHBOX` | body to body collision between fighters |
| 3 | `HURTBOX_TEAM_0` | team 0 hurtboxes |
| 4 | `HURTBOX_TEAM_1` | team 1 hurtboxes |

An attacker on team 0 queries with `CollisionLayers.opponent_hurtbox_mask(0)`,
which returns team 1's hurtbox layer. Team filtering happens in the query mask,
not through owner comparisons inside the loop.

## Frame flow

```
Fighter._physics_process (per fighter)
  1. hitstop_frames > 0  -> freeze and bail out
  2. hitbox_manager.advance()      # attack_frame += 1
  3. state_machine.physics_update()
  4. gravity + move_and_slide()

CollisionSolver._physics_process   # process_physics_priority = 100
  5. for each attacker, for each active hitbox: intersect_shape
  6. build the HitData of every hit this frame
  7. only then apply: victim.apply_hit() / attacker.apply_hit_landed()
```

Step 6 before step 7 is what allows **trades**: both sides confirm their hit
before either one enters hitstun or hitstop.

The high physics priority guarantees the solver runs after every fighter has
moved, regardless of their order in the scene.

## Frame counting

`attack_frame` starts at `0` on the frame `start_attack()` was called, and
`advance()` runs before the state machine. An attack with `startup_frames = 5`
has its first hitbox active at `start_frame = 5`.

```
frame:   0  1  2  3  4 | 5  6  7 | 8 ... 19
         startup        | active  | recovery
```

During hitstop the fighter does not call `advance()`, so active frames freeze
along with everything else. Re-hitting with the same move is prevented by the
`hit_group` record, not by frame counting.

## Authoring a move

`AttackData` is a `.tres` holding the list of `Hitbox`:

```gdscript
var jab := AttackData.new()
jab.attack_id = &"5P"
jab.startup_frames = 4
jab.active_frames = 3
jab.recovery_frames = 8
jab.damage = 400
jab.hitstun = 16
jab.blockstun = 12
jab.hitstop = 6
jab.guard = AttackData.Guard.MID

var box := Hitbox.new()
box.shape = RectangleShape2D.new()
box.offset = Vector2(60, -20)   # always in facing-right space
box.start_frame = 4             # == startup_frames
box.end_frame = 6               # start + active - 1
jab.hitboxes = [box]
```

Advantage on hit and block are **not authored**: `get_advantage_on_hit()` and
`get_advantage_on_block()` derive from the frame data, so there is no duplicated
value able to lie about the move.

`recovery_on_hit` is the one move that changes what "the frame data" means. Left
at `-1` a move owes the same recovery whether it lands or whiffs, which is what
a normal wants. Set, it owes that many frames from the frame it connects, and
the `HitboxManager` brings the end of the move forward to match. A throw needs
it: a punishable whiff and a hit that gives the fighter their turn back cannot
be the same number.

Offsets are always written facing right and mirrored at runtime by
`get_query_transform()`. Negative node scale is never used to turn a fighter
around: only the `Visuals` node flips, boxes are mirrored in code.

### Multi-hit

Hitboxes sharing a `hit_group` count as a single blow — useful to describe a
wide move made of several boxes without hitting twice. For a move that really
does hit twice, use different groups:

```gdscript
box_hit_1.hit_group = 0   # frames 8..10
box_hit_2.hit_group = 1   # frames 14..16
```

## Hurtboxes

They are `Area2D` nodes with the `Hurtbox` script and `CollisionShape2D`
children authored in the fighter scene (see
`content/fighters/training_dummy/fighter.tscn`). Each `Hurtbox` must sit at the
**center of its own box**: it is the node position that gets mirrored when the
fighter turns around.

The `HitboxManager` scans the fighter subtree on `_ready` and registers them all.

- `height` (`HIGH` / `MID` / `LOW`) classifies the box for anti-airs and
  overheads.
- `set_invulnerable(true)` takes the fighter out of query range without touching
  the scene — that is how reversal and wakeup invincibility frames will work.

## Hit resolution

`HitData.build()` produces the final result; the receiving side reinterprets
nothing.

**Guard** — `Fighter.can_block()`. Blocking means holding back, not pressing a
button (see [input.md](input.md)). Air moves are authored as `HIGH`, which is
what makes jumping in an overhead; the dust is the grounded one, and the only
one a character gets without leaving the floor:

| `Guard` | Blocks |
|---|---|
| `MID` | standing or crouching |
| `HIGH` | standing only (overhead) |
| `LOW` | crouching only |
| `UNBLOCKABLE` | never |

Blocked: takes `chip_damage` and enters blockstun. Not blocked: takes scaled
damage and enters hitstun.

**Damage scaling** — every hit already taken in the combo removes
`scaling_per_hit` (10% by default), floored at `min_damage_scaling`.
`Fighter.combo_hits` goes up on every clean hit and resets when the fighter
leaves hitstun. Without this, a long combo turns into an infinite match.

**Counter hit** — hitting during the opponent's startup. Multiplies damage and
adds hitstun.

**Knockback** — `AttackData.knockback.x` always points away from the attacker;
the solver orients it by facing and divides it by the target's `weight`.

**Hitstop** — both sides freeze for the same frames. It takes
`maxi(current, new)`, so a hit during hitstop never shortens the freeze.

## Usage

`BattleManager` already creates the solver and registers the fighters, so
normally you just trigger the move:

```gdscript
fighter.perform_attack(attack_data)
fighter.perform_attack_by_id(&"5P")   # looked up in fighter_data.moves
```

Setting it up by hand, outside a match:

```gdscript
var solver := CollisionSolver.new()
add_child(solver)
solver.register_fighter(player_1)
solver.register_fighter(player_2)
solver.hit_resolved.connect(_on_hit_resolved)
```

Useful signals: `Fighter.hit_taken`, `Fighter.hit_landed`,
`Fighter.health_changed`, `Fighter.died`, `CollisionSolver.hit_resolved`.

## Test

`tests/hitbox_smoke_test.gd` sets up two fighters, a solver and three scenarios
(clean hit, blocked move, low move against a standing guard) without opening the
editor:

```sh
godot --headless --path . --script tests/hitbox_smoke_test.gd
```

## Pushbox

Fighters are **not physics obstacles to each other**: their bodies sit on the
`PUSHBOX` layer and only mask `WORLD`, so they collide with the stage and never
with an opponent. If they collided as bodies, landing on someone's head would
leave both stuck up there with neither able to hit the other.

`PushboxSolver` (`engine/collision/pushbox_solver.gd`) separates them instead,
and only **horizontally**:

- The push is skipped while either fighter is airborne. That is what lets a
  jump pass over the opponent and land on the other side, and it is why
  crossups exist.
- Separation is split between both fighters and capped per frame, so landing
  fully overlapped resolves over a few frames instead of teleporting them apart.
- Width comes from `FighterStats.pushbox_width`: a bigger character takes more
  space and loses ground faster in the corner.

It runs at physics priority 90, before the hit solver, so hitbox queries always
see final positions.

```sh
godot --headless --path . --script tests/pushbox_smoke_test.gd
```

## Throws

A throw is an ordinary `AttackData` with `is_throw` set: its throwbox is a
`Hitbox` queried the same way, against the same hurtbox layer. What changes is
what `CollisionSolver._resolve` does with the result — a grab ignores the guard,
only catches an opponent who is grounded and in control, and breaks against
another throw instead of connecting.

Every character has `6D` and `4D` without authoring them. The whole mechanic is
in [throws.md](throws.md).

## Not implemented yet

- Proximity guard (automatic block when a hitbox comes close).
- Per state hurtboxes (crouching shrinks, airborne changes height).
