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

## Networking

**`src/game/profiles.gd`** draws the line the whole feature depends on: a
*map* is a template (a name and a seed — the same valley for everybody, the
way a Call of Duty map is), a *world* is one played copy of a map, and a
*player* is a child's own name and progress, who can own worlds and be
invited into someone else's. Save data splits along exactly this line —
`save_path_for(player, world_id)` for the bag, coins and journal;
`world_path_for(world_id)` for structures, felled trees, campfires and dams —
so two children in one world see the same house but keep separate coins, and
the same child's two worlds share nothing but the seed they were both made
from.

**`src/net/session.gd`** is Godot's high-level multiplayer
(`ENetMultiplayerPeer`) on a fixed port, deliberately host-light: a guest
places its own piece immediately and *reports* it, rather than waiting for
the host to approve it. This is a family game, not a competitive shooter — a
child whose wall is refused because of network latency has been told the
game is broken. Terrain, vegetation and everything else generated from the
seed is never sent; only positions (rate-limited, unreliable) and the
handful of events that change the world (built, removed, felled, a stick
given to a dam) travel, reliably, once each.

**The short join code.** `192.168.1.161` is fifteen characters of dots and
digits — unreadable to a six-year-old and a typing task for a ten-year-old.
Two devices on one family network differ only in the last number, so
`Session.code_for()`/`address_for_code()` reduce the address to that one
number, assuming both devices share the same /24 prefix. The host shows one
large number; the guest taps it on an on-screen keypad. There is no text
entry anywhere in the together screen.

**`src/net/voice.gd`** is push-to-talk, on purpose and structurally: the
microphone is *stopped*, not merely muted, between presses; the Android
permission is requested the first time a child actually presses talk, not at
launch; nothing is ever written to disk; and voice only reaches children
already inside the same session — there is no lobby or discovery to overhear
from. A dedicated check reads the source itself (with comments stripped, so
it cannot be fooled by a comment that merely mentions the forbidden word) to
hold all of that structurally rather than by convention.

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
  │     └── Lakes, Paths, Places   dependency-free leaves the height field asks
  │     └── Hearths                campfires: fuel, warmth, the flame itself
  │     └── Animals, Mounts        wandering creatures and what can be ridden
  │     └── Ambience, AnimalVoices synthesised sound, positional and event-based
  └── Player             the body, its controller, its camera rig
  └── Structures         what has been built, and what it has become since
  └── BuildMode          the ghost, the snapping, the overlap rule
  └── Hud                every on-screen control, including TogetherPanel
  └── Session, Visitors, Voice     LAN multiplayer, the other children, talk
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

**Rebuilding is not one queue.** A chunk needs rebuilding either because it
must become *better* — finer detail, or collision it lacks — or only because
it could now afford to become *coarser*. Treating both the same way rebuilt
roughly a fifth of all in-range chunks every 64 m walked, oscillating
graphics memory between two values a hundred and fifty megabytes apart and
reading, on the tablet, as a stutter every so often for no visible reason.
Now only the "better" case is urgent; coarsening happens lazily, one chunk a
frame, furthest first, whenever nothing urgent is queued.

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
  scene tree starts processing never receives `_ready` — and, separately, a
  script that adds a node to its own headless `SceneTree` (as every check
  does) does not get `_ready` for free the way a node added to an
  already-running game does either. `_ready` is reserved for the few things
  that genuinely need the tree, such as `get_viewport()`; everything else
  goes in `_init`. This has now been the actual bug behind more than half a
  dozen separate fixes — `Hud` and `Atmosphere` are the most recent — which
  is the point of writing it down here rather than trusting memory.
- Two `class_name` scripts must never reference each other. A cyclic dependency
  hangs Godot's loader outright; shared constants go in a leaf script.
- Never iterate a bare, untyped array literal in a `for` loop. GDScript
  cannot infer a type for the loop variable from one, which silently makes it
  `Variant` and can turn a later typed assignment into a parse error — a bug
  that has cost this project real time more than once. CI rejects the bare
  form; annotate the loop variable's type explicitly instead
  (`for code: StringName in [...]`), which is a smaller change than
  rewriting the literal itself into a typed array and fixes the same defect.
- Positions are absolute. Nodes that hold world-placed children stay at the
  origin, so `position` and `global_position` agree.
- A check that reads source to enforce a rule must strip comments first
  (`_code_only()` in `ci_check.gd`). Twice now, a check has flagged the
  comment explaining the very rule it enforces rather than any real
  violation.
