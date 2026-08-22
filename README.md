# Fight Core

I'm a Brazilian programmer building a 2D fighting game engine from scratch with
Godot 4.7. I sometimes use AI to help translate my writing into English.

> **Early days.** The engine underneath is real and tested, but the game on top
> of it is not: fighters are coloured polygons, there is no sound, no menus and
> one placeholder character. It is a foundation you can fight in, not a game
> you can play yet. See [docs/roadmap.md](docs/roadmap.md) for what is missing.

## What it does

- **Deterministic and frame locked:** Every fight system runs in `_physics_process`
  at a fixed 60hz and counts integer frames. Hits resolve with a direct PhysicsServer query on the same frame instead of `Area2D` signals, which arrive a frame late.
- **Data driven:** Frame data, stats, moves and cancel routes are `.tres`
  resources. A character is a scene plus a folder of resources, and no engine code is specific to any character.
- **Combat:** Hitboxes and hurtboxes with guard height, blocking with chip damage, hitstop, damage scaling, pushboxes, cancels with a gatling ladder, jump cancels, air normals, double jump and air dash.
- **Throws:** `6D` and `4D` are a grab every character has without authoring it.
  They only reach at point blank, they go through a guard, and they pop the opponent up for a hit or two. `4D` swaps sides. If both players go for a throw within ten frames it breaks and pushes them apart instead of landing.
- **Combos that end:** Juggle gravity, knockdown and wakeup close the air route,
  so a combo terminates and the defender gets a window to respond instead of the same sequence repeating.
- **Matches:** Rounds, a frame counted clock, KO / timeout / draw conditions and
  a full reset between rounds.
- **Input:** Buffering, SOCD handling, motion commands, stance dependent moves,
  keyboard and gamepad bindings.

## Running it

Needs [Godot 4.7](https://godotengine.org/). Open the project and press F5, it will launch straight into the training room.

| | P1 | P2 |
|---|---|---|
| Move | `WASD` | arrow keys |
| Punch / Kick / Slash / Heavy / Dust | `J` `K` `L` `U` `I` | numpad `1`..`5` |

Gamepad: d-pad or stick, `A`=P `B`=K `X`=S `Y`=HS `RB`=D. `F1` toggles the hitbox overlay, `F2` restarts the match.

Try `236` + `S` for the special, and the gatling ladder `P > K > S > HS > D`. Any normal cancels into `236S`. Hold forward or back with `D` to throw.

## Tests

Everything is verifiable headless:

```sh
# does everything compile?
godot --headless --path . --script tests/script_load_test.gd 2>&1 \
	| grep -q "Failed to load script" && echo BROKEN

# behaviour
godot --headless --path . --script tests/hitbox_smoke_test.gd
godot --headless --path . --script tests/training_scene_smoke_test.gd
```

`tests/` holds one smoke test per system, [docs/archtecture.md](docs/archtecture.md#checking-the-project) lists them all and explains what each check catches.

## Documentation

| | |
|---|---|
| [archtecture.md](docs/archtecture.md) | layout, engine rules, frame flow **[start here]** |
| [fighter_format.md](docs/fighter_format.md) | how a character is defined |
| [hitboxes.md](docs/hitboxes.md) | hit resolution and box types |
| [state_machine.md](docs/state_machine.md) | fighter states |
| [cancels.md](docs/cancels.md) | cancel and gatling rules |
| [throws.md](docs/throws.md) | the system throw and the break |
| [input.md](docs/input.md) | buffer, motions and commands |
| [battle.md](docs/battle.md) | match, rounds and clock |
| [roadmap.md](docs/roadmap.md) | what is missing, and in what order |

## Contributing

Everything written in this repository is in English: code, comments, docs, on-screen text and commit messages. Commits are a single line with a conventional-commit prefix and no body; anything that needs explaining goes in `docs/`, where it can be found later. The full conventions are in [CLAUDE.md](CLAUDE.md).

## License

MIT. See [LICENSE](LICENSE)
