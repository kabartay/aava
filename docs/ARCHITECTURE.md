# Architecture

How Aava is put together, and why. Read `DESIGN.md` first for what the game is
trying to be; this document is about the code.

## Systems added after the first release

**`src/game/vitals.gd`** — energy and water as a plain `RefCounted` with signals
and no node of its own. It is a model: it knows nothing about the player, the
river, or the interface, which is why it can be exhaustively checked without
constructing a world. The game feeds it what the player did each frame and reads
back whether running is still allowed.

**`src/world/animals.gd`** — streaming, wandering, shyness, and the care
transaction. Animals are `Dictionary` records rather than a class, which is
adequate at four species and will not be at ten (see ROADMAP.md, Known debt).

**`src/shop/`** — `wallet.gd` holds coins and what has been bought;
`shop_stock.gd` is a dependency-free leaf listing prices. The split follows the
same rule as `terrain_spec.gd`: anything two systems both need to know sits in a
leaf that references nothing.

**Handlers are named, not positional.** `Wiring.connect_hud` takes a dictionary
of callables keyed by name and reports any that are missing. It reached
seventeen positional parameters first, which made adding a control an exercise
in counting commas at three call sites.

**Icons are drawn, not rendered.** `part_icon.gd` and `shop_icon.gd` use the 2D
primitives rather than a viewport per thumbnail. A viewport per button would
cost eight extra render passes to show eight pictures, and a wall seen head-on
is a rectangle either way. Both draw against `custom_minimum_size`, never
`size` — see LESSONS.md for why.

## The one rule

**The height field is the single source of truth for where the ground is.**

`src/world/height_field.gd` is a pure function of `(x, z)` plus a seed. The
terrain mesh, the collision heightmap, the tree scattering, the pickups, the
boulders, the football pitch, the minimap and the build placement all ask it.
There is deliberately no second opinion about the ground anywhere in the
codebase, which is what stops trees floating, players falling through hills, and
a map that disagrees with the world it describes.

Anything that changes the shape of the world therefore belongs *inside* the
height field, not on top of it. The football pitch is the worked example: it
levels the ground under itself by being consulted from `height_at()`, so the
mesh, the collision and the planting all know about it without any of them
having heard of football.

## Layers

```
main.gd                  the only place that knows about both world and game
  └── World              terrain, water, sky, plants, pickups, rocks, football
  └── Player             the body, its controller, its camera rig
  └── Structures         what has been built, and what it has become since
  └── BuildMode          the ghost, the snapping, the overlap rule
  └── Hud                every on-screen control
```

The world does not know it is being played. It streams terrain and scatters
sticks and asks nothing of anyone; `main.gd` wires the game to it. That
separation is why the screenshot tool can build a real world without a game.

## Everything is generated

There is no hand-placed scene content. The whole world is one integer, which is
partly a consequence of how this project is written — from a terminal, without
the Godot editor — and partly the only way one person gets a world large enough
that a ten-year-old does not exhaust it in an afternoon. It also means any bug
can be reproduced by sharing a seed.

The one thing placed by hand is placed by the child, and that is the game.

## Streaming

Terrain, vegetation, pickups and boulders all follow the same pattern: a manager
that keeps a dictionary of live tiles keyed by coordinate, a queue of tiles to
build, and a small budget of tiles built per frame. Placement inside a tile is
derived from `hash(seed, tile)` so a tile that streams out and back comes back
identical — otherwise the forest rearranges itself behind the player's back.

Anything a player has consumed is remembered by id (`taken`, `cleared`) rather
than by removing it from the generator, for the same reason.

## Wiring

`src/game/wiring.gd` connects the interface to the game, and is called by both
`main.gd` and the screenshot tool. This exists because the tool once wired
itself and was one signal short, so it photographed a game where build mode
could not activate. Two places connecting the same objects will always drift;
one will not. Adding a control means adding a parameter here, and the compiler
then refuses to build until every call site agrees.

## Text

`src/i18n/text.gd` holds every user-visible string in English, French and
Russian. Keys are identifiers, not English text, so rewording the English does
not silently orphan the other languages. A missing key returns `?key` and the
checks fail on it.

Godot's own translation system was not used: it expects `.po` files and a build
step, which is the right answer for a thousand strings and a translation agency
and the wrong one for forty strings and a father who may want to fix a clumsy
phrase.

## Working without the editor

Two tools make this possible and must keep working.

`dev/capture.tscn` builds the real world — the same `World` class the game uses
— parks a camera, and writes a PNG. It also prints what is actually in the
scene: chunk and triangle counts, plant and pickup counts, where the camera
ended up, how far it stands from the player. A screenshot cannot distinguish
"the camera is pointing the wrong way" from "the geometry was never built", and
guessing between those two costs far more than printing the answer.

`src/dev/ci_check.gd` is the numeric suite. Every assertion in it corresponds to
a bug that actually happened; see `LESSONS.md`.

## Conventions

- Resources are created in `_init`, never in `_ready`. A node used before the
  scene tree starts processing never receives `_ready`, and the failure is
  silent.
- Two `class_name` scripts must never reference each other. A cyclic dependency
  hangs Godot's loader outright; shared constants go in a leaf script.
- Never iterate a bare array literal. GDScript cannot infer element types from
  one, and CI rejects it.
- Positions are absolute. Nodes that hold world-placed children stay at the
  origin, so `position` and `global_position` agree.
