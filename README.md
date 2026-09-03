# Aava

An open world that comes alive as you build in it.

A 3D exploration-and-building game made for two brothers, aged 10 and 6, with a
1.5-year-old and their parents living in the world as its first inhabitants.

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
the screen, sprint with shift, jump with space. The stick is Godot 4.7's native
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

The last two exist because a screenshot cannot tell you whether the colours are
wrong or the light is wrong, and guessing between the two is expensive. The tool
also prints how many chunks and triangles were actually built and where the
camera ended up — which is how the inverted triangle winding that made the whole
valley invisible from above was finally caught.

There is also a numeric probe for questions an image cannot answer at all:

```sh
godot --headless --path . --script src/dev/probe.gd
```

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
  player/
    player.gd          the controller: acceleration, coyote time, jump buffer
    camera_rig.gd      third-person camera that glides instead of ticking
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
