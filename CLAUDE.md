# FightCore

2D fighting game engine in Godot 4.7. Start at [docs/archtecture.md](docs/archtecture.md).

## Language

**Everything in this repository is written in English.** No exceptions.

That covers identifiers, comments, docstrings, everything under `docs/`, the
README, on-screen text (HUD, help, move names), test output and commit
messages. The repository is public and meant to take outside contributions, so
a reader who does not speak Portuguese has to be able to use all of it.

Conversation with the author happens in Portuguese. That does not change what
gets written to a file — the language of the chat never leaks into the repo.

## Commits

One line. Conventional-commit prefix, lowercase, imperative, no body.

```
feat(engine): add input buffer
fix(stage): fix wall collision
docs(roadmap): add camera slice
test(character): cover wakeup invincibility
chore(content): backfill tres uids
```

No description, no bullet list, no trailers, no explanatory paragraph. If a
change needs explaining, it belongs in `docs/`, where people will actually find
it — not in a commit message.

Scope is the area touched (`engine`, `character`, `physics`, `collision`,
`battle`, `input`, `content`, `stage`, `roadmap`), and can be dropped when the
change is repository-wide.

## Working rules

- All fight logic runs in `_physics_process` at 60 Hz. Never `await`, `Timer`
  or anything counted in seconds for frame-critical logic.
- Frame data and stats live in `.tres` resources, never as script constants.
  Resources are shared between fighters, so they never hold runtime state.
- Hits resolve through a direct PhysicsServer query, never through `Area2D`
  signals — see [docs/hitboxes.md](docs/hitboxes.md).

The full set is in [docs/archtecture.md](docs/archtecture.md#engine-rules).

## Checking the project

Godot is not on the `PATH` on the author's machine. The commands and what each
one actually catches are listed in
[docs/archtecture.md](docs/archtecture.md#checking-the-project). The load scan
is the only check that catches every compile error; run it before committing.
