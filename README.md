# Aava

An open world that comes alive as you build in it.

A 3D exploration-and-building game made for two brothers, aged 10 and 6, with a
2-year-old and their parents living in the world as its first inhabitants.

You arrive in an empty valley. Everything you build makes it more alive, and the
more alive it is, the more it gives back: plant a grove and birds arrive, dig a
pond and reeds grow at its edge, raise a house and someone moves in with a craft
you did not have before. Creation is the engine of the game, not its decoration.

## Running it

Requires [Godot 4.7](https://godotengine.org) or newer. No other dependencies.

```sh
godot --path .                       # play
godot --path . -- --seed=12345       # play a different valley
```

Move with the on-screen stick or WASD, look around by dragging anywhere else on
the screen, sprint with shift, jump with space. Walk over a stick, a stone, a
reed or a seed and you pick it up — there is no button for gathering, because
walking into things is something a six-year-old understands without being told.
Tap **build** to open the palette; the ghost shows what will be placed, green
when it can be and red with the reason when it cannot.

Plant three saplings close together, keep playing, and they grow. When all three
are full trees the place becomes a grove and birds arrive. That loop — build,
and the world answers — is what the whole game is for. The stick is Godot 4.7's native
`VirtualJoystick`, so both fingers work at once without any index bookkeeping:
the viewport keeps routing each finger to the control it first landed on.

Every world is one integer. There is no hand-placed scene content anywhere in
this project: the valley, the river, the mountains and everything scattered on
them are generated from the seed, which is the only way one person can make a
world large enough not to be exhausted in an afternoon. It also means any bug
can be reproduced by sharing a number.

## Looking at it without the editor

This project is written from a terminal, so there is a tool whose whole job is
to answer "what does it actually look like right now":

```sh
godot --path . res://dev/capture.tscn -- \
      --out=/tmp/shot.png --pos=-2,4,30 --look=26,1.2,-6 --time=0.40
```

| Flag | Meaning |
| --- | --- |
| `--out=PATH` | where to write the PNG |
| `--pos=x,y,z` | camera position |
| `--look=x,y,z` | what it points at |
| `--time=0..1` | time of day, `0.5` is noon |
| `--seed=N` | which valley |
| `--nowater=1` | hide the water sheet, to see the ground under it |
| `--unshaded=1` | draw terrain as flat vertex colour, no lighting |
| `--player=1` | spawn the real player and shoot through the game camera |
| `--yaw=DEG`, `--pitch=DEG` | aim that camera |
| `--demo=1` | stand a finished camp and a grown grove in front of the player |
| `--build=1` | open build mode with the ghost preview showing |

The last two exist because a screenshot cannot tell you whether the colours are
wrong or the light is wrong, and guessing between the two is expensive. The tool
also prints how many chunks and triangles were actually built and where the
camera ended up — which is how the inverted triangle winding that made the whole
valley invisible from above was finally caught.

There is also a numeric probe for questions an image cannot answer at all:

```sh
godot --headless --path . --script src/dev/probe.gd
```

And the checks CI runs, which are worth running by hand before a commit:

```sh
godot --headless --path . --script src/dev/ci_check.gd
```

Every assertion in there corresponds to a bug that actually happened. The one
that earns its keep most often is the pickup count: it caught a world with
nothing to find, because resources were being built in `_ready`, which never
runs for a node used before the scene tree starts.

## On an Android tablet

The Android preset is committed, so a build is one command. It uses Godot's
prebuilt template rather than a Gradle build, which means no Gradle and no
Android project directory — just the SDK and a JDK.

```sh
godot --headless --path . --export-debug "Android" build/aava.apk
adb install -r build/aava.apk
```

What has to be set once, in Godot's editor settings:

| Setting | Value |
| --- | --- |
| `export/android/android_sdk_path` | `~/Library/Android/sdk` |
| `export/android/java_sdk_path` | a real JDK 17+ |
| `export/android/debug_keystore` | a debug keystore |
| `export/android/debug_keystore_user` | `androiddebugkey` |
| `export/android/debug_keystore_pass` | `android` |

Two things that cost time if you do not know them. `/usr/bin/java` on macOS is a
stub that only tells you to install Java, so `java -version` succeeding proves
nothing — point `java_sdk_path` at a real JDK, such as the one Android Studio
bundles at `Contents/jbr/Contents/Home`. And
`rendering/textures/vram_compression/import_etc2_astc` must be on or the export
aborts, because Android requires ETC2/ASTC textures.

iPad needs a paid Apple developer account and is not set up yet.

## Two traps worth knowing

**Anchor ignore patterns.** A plain `build/` line in `.gitignore` matches at
every level, including `src/build/`. The whole building system was silently kept
out of the commit that added it: the game ran perfectly here and CI failed with
`Could not find type "Structures"`, because CI was the first machine to see the
tree as it had actually been pushed. Ignore patterns for build output are now
written `/build/`.

**Import twice on a clean checkout.** Global `class_name` types only exist once
`.godot/global_script_class_cache.cfg` has been written, and on a fresh clone
that file is written by the same pass that parses the scripts. Your own machine
never shows this, because the cache is left over from last time.

```sh
godot --headless --path . --import   # writes the class cache
godot --headless --path . --import   # this one should be silent
```

To see the project as a fresh clone sees it, delete `.godot/` first — and check
`git ls-files src` against what is actually on disk.

## Layout

```
src/
  main.gd              entry point: reads the seed, builds the world
  world/
    height_field.gd    the shape of the world as a pure function of (x, z)
    terrain_spec.gd    shared terrain constants, dependency-free on purpose
    terrain.gd         chunk streaming and detail rings
    terrain_chunk.gd   one square of ground: mesh, vertex colours, collision
    water.gd           the water sheet and its shader
    atmosphere.gd      sky, sun, time of day
    plant_meshes.gd    trees and grass, built from primitives in code
    vegetation.gd      planting, streamed in tiles around the player
    vegetation_tile.gd one tile of planting: a MultiMesh per plant kind
    world.gd           assembles the above; the one place a world comes from
    pickups.gd         sticks, stones, reeds and seeds, streamed and gathered
    birds.gd           the world answering: birds over feeders and groves
  player/
    player.gd          the controller: acceleration, coyote time, jump buffer
    camera_rig.gd      third-person camera that glides instead of ticking
  build/
    build_kinds.gd     what can be built, what it costs, what it grows into
    structures.gd      what has been built, and what it has since become
    build_mode.gd      the ghost preview, snapping, and the one overlap rule
  game/
    item_kinds.gd      what can be picked up
    inventory.gd       what is being carried
    save_game.gd       the one save file, as readable JSON
    wiring.gd          how the interface and the game are connected, once
  ui/
    camera_pad.gd      the look-around touch layer
    hud.gd             the two on-screen controls, and nothing else
  input_actions.gd     input actions, registered in code
  dev/
    capture.gd         screenshot tool
    probe.gd           headless numeric probe
```

`height_field.gd` is the single source of truth for where the ground is.
The mesh, the collision heightmap, and later every tree, animal and building ask
it — there is deliberately no second opinion about the ground anywhere, which is
what keeps trees from floating and the player from falling through hills.

## Design

See [docs/DESIGN.md](docs/DESIGN.md).

## Licence

GPL-3.0. See [LICENSE](LICENSE).
