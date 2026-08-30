# Fighter Format

A character is a folder under `content/fighters/<id>/` holding a scene and
`.tres` resources. No engine code is character specific: the character script
only has to extend `Fighter`.

## Folder layout

```
content/fighters/training_dummy/
├── fighter.tscn          character scene
├── fighter.gd            extends Fighter
├── fighter_data.tres     FighterData: identity, stats, moves
├── moves/                one AttackData .tres per move
└── config/
    └── fighter_stats.tres  FighterStats
```

## Scene

The scene needs these nodes, with these names — `Fighter` looks them up by a
fixed path:

```
TrainingDummy (CharacterBody2D + script extending Fighter)
├── Visuals (Node2D)             the only node that flips scale
├── CollisionShape2D             body against the stage only, never the opponent
├── StateMachine (FighterStateMachine)
│   ├── Idle, Walk, Jump, Crouch, Block, Hitstun, Attack, AirDash,
│   │   Knockdown, Wakeup, ThrowBreak, KO
├── HitboxManager                owner of the boxes
├── Input (InputBuffer)          optional: without it the fighter never acts
└── Hurtboxes (Node2D)
    ├── Body (Hurtbox, height = MID)
    └── Head (Hurtbox, height = HIGH)
```

`Visuals`, `StateMachine` and `HitboxManager` are required. Hurtboxes can sit
anywhere in the subtree: the `HitboxManager` scans everything below the fighter
on `_ready`.

Each `Hurtbox` must sit at the **center of its own box**, because it is the node
position that gets mirrored on flip. See [hitboxes.md](hitboxes.md).

## Resources

### FighterData

`engine/character/fighter_data.gd` — identity and content of the character.

| Field | Type | Use |
|---|---|---|
| `fighter_id` | `StringName` | internal id, matches the folder name |
| `display_name` | `String` | shown name |
| `portrait` | `Texture2D` | select screen portrait |
| `sprite_frames` | `SpriteFrames` | animations |
| `stats` | `FighterStats` | the character's numbers |
| `moves` | `Array[AttackData]` | moves |
| `commands` | `Array[CommandData]` | inputs that trigger the moves — [input.md](input.md) |

A character does not list the system moves every fighter has. `Fighter` merges
those in on `_ready`, which is why `6D` and `4D` work on a character whose
`commands` never mention them — see [throws.md](throws.md).

### FighterStats

`engine/character/fighter_stats.gd` — the numbers that balance the character.

| Field | Default | Use |
|---|---|---|
| `max_health` | 10000 | full health; 10k to 15k gives ~20s rounds |
| `max_meter` | 10000 | super meter |
| `walk_speed` | 150.0 | px/s while walking |
| `dash_speed` | 400.0 | px/s while dashing |
| `jump_velocity` | -650.0 | jump impulse (negative goes up) |
| `gravity` | 1800.0 | px/s² |
| `air_jumps` | 1 | extra jumps before landing |
| `air_jump_velocity` | -560.0 | weaker than the ground jump, so it is a commitment |
| `air_dashes` | 1 | air dashes before landing |
| `air_dash_speed` | 420.0 | px/s during the dash |
| `air_dash_frames` | 18 | how long the dash suspends gravity |
| `juggle_gravity_per_hit` | 0.12 | extra gravity per point of juggle |
| `max_juggle_gravity` | 2.2 | ceiling for the juggle multiplier |
| `knockdown_frames` | 24 | time lying on the floor — the okizeme window |
| `wakeup_frames` | 16 | length of the rise, invulnerable throughout |
| `pushbox_width` | 46.0 | space the fighter holds against the opponent |
| `knockback_friction` | 1600.0 | px/s² bleeding off ground knockback while stunned |
| `weight` | 1.0 | divides incoming knockback |
| `defense_multiplier` | 1.0 | multiplies incoming damage |

### AttackData

`engine/character/attack_data.gd` — frame data and hit properties of a move,
plus the cancel routes. Documented in [hitboxes.md](hitboxes.md) and
[cancels.md](cancels.md).

`jump_cancellable` lets the move be cancelled into a jump by holding up, which
is how a launcher leads into an air combo — see [cancels.md](cancels.md). No
shipped move sets it: the launch belongs to the throw, which does not jump
cancel.

`recovery_on_hit` lets a move owe fewer frames when it connects than when it
whiffs. `-1`, the default, uses `recovery_frames` for both. The system throw is
what needs it — see [throws.md](throws.md) — but nothing about it is throw
specific.

`ends_on_landing` marks an air move: it keeps the jump arc instead of planting
the fighter, and it is cut short the moment the fighter touches the ground.
Authored rather than read from `is_on_floor()`, because that flag only updates
after a move and would misread a move started on the landing frame.

`causes_knockdown` gives a grounded hit the sweep property: the victim ends up
on the floor instead of back in neutral. An airborne victim always knocks down,
flag or not — see [state_machine.md](state_machine.md).

`launcher` and `juggle_cost` drive the juggle. A launcher opens it even though
it connects on a grounded opponent; after that every hit taken in the air adds
its `juggle_cost` to the victim's `juggle_count`, and that counter multiplies
their gravity. Heavier enders cost more juggle, which is how a route is closed
by data instead of by a hardcoded hit limit. A blocked hit costs nothing.

### CommandData

`engine/character/command_data.gd` — binds an input (motion + button + stance)
to an `AttackData`. Documented in [input.md](input.md).

## Character script

```gdscript
extends Fighter
```

That is all. `Fighter` handles health, facing, gravity, hitstop, hit reactions
and guarding. The character script exists for behaviour unique to that
character.

## Fighter API

`engine/character/fighter.gd`.

**State**

| Member | Use |
|---|---|
| `fighter_data` | the character's resource |
| `team` | sets the hurtbox layer and who this fighter can hit |
| `opponent` | used by `update_facing()` |
| `facing_right` | which way the fighter looks |
| `health` | current health |
| `combo_hits` | hits taken in the current combo, basis for scaling |
| `juggle_count` | juggle built up in the air, raises this fighter's gravity |
| `hitstop_frames` | remaining freeze frames |
| `throw_tech_frames` | frames left in which this fighter's throw answers an incoming one |
| `frozen` | round pause: no state logic, no gravity |
| `commands` | the character's commands plus the system moves — [throws.md](throws.md) |
| `stats` | shortcut to `fighter_data.stats` |

**Movement**: `walk(direction)`, `jump()`, `update_facing()`, `set_facing()`.

**Combat**: `perform_attack(attack, force)`, `perform_attack_by_id(id)`,
`get_attack(id)`, `apply_hit(hit)`, `apply_hit_landed(hit)`,
`apply_hitstop(frames)`, `can_block(guard)`, `is_blocking()`, `is_crouching()`,
`can_be_hit()`, `can_be_thrown()`, `break_throw(attack, away)`, `reset_combo()`,
`reset_for_round()`.

**State queries**: `can_act()` (free to take a command), `can_turn()` (allowed
to turn around), `can_start_attack(attack)` (cancel rules — [cancels.md](cancels.md)),
`is_in_stun()`, `is_throw_broken()`, `is_teching_throw()`, `is_alive()`.

**Signals**: `health_changed`, `hit_taken`, `hit_landed`, `died`.

## Creating a new character

1. Copy `content/fighters/training_dummy/` to `content/fighters/<id>/`.
2. Set `fighter_id` and `display_name` in `fighter_data.tres`.
3. Tune the numbers in `config/fighter_stats.tres`.
4. Resize the scene hurtboxes to the character's body.
5. Create the moves' `AttackData` under `moves/` and list them in `moves`.
6. Create the `CommandData` that triggers each move and list them in `commands`.
