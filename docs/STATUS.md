# Status

What exists in the game today, and how finished each part is. Written so that
someone returning after a month knows what they can play and what they cannot.

Last updated: 2026-09-04.

## Legend

- **Done** — implemented, covered by checks, seen working in a screenshot.
- **Partial** — usable, but a stated part of it is missing.
- **Stub** — the object exists; the behaviour behind it does not.

## The world

| Part | State | Notes |
|---|---|---|
| Terrain | Done | Procedural from one integer seed, 1216 m across, streamed in 64 m chunks with LOD rings. |
| Height field | Done | A pure `height_at(x, z)`. Every other system asks it rather than keeping its own idea of the ground. |
| River | Done | A meander from two sine waves; carves its own bed through the height field. |
| Water surface | Done | Custom shader. Does not use `DEPTH_TEXTURE`, which 4.7 removed. |
| Sky and light | Done | Procedural sky, AGX tonemapping, depth fog, time-of-day setting. |
| Vegetation | Done | 5,482 plants per view via `MultiMeshInstance3D`, tiled so culling works. |
| Boulders | Done | 90 in view; the jumpable ones award points. |
| Birds | Done | Ambient, drawn from the same vertex-colour material as everything else. |

## Play

| Part | State | Notes |
|---|---|---|
| Walking, running, jumping | Done | `CharacterBody3D`, coyote time, jump buffer, floor snapping. |
| Camera | Done | `SpringArm3D` with a top-level camera and exponential smoothing; excludes the player's own capsule. |
| Zoom | Done | Distance only — the aim point does not move, so zooming never disorients. |
| Football pitch | Done | Levelled inside the height field itself, so the ground is flat by construction rather than by flattening afterwards. |
| Balls and kicking | Done | `RigidBody3D` with continuous collision detection. Kick sets velocity directly. |
| Kick power and loft | Done | Held button charges 3.2–26 m/s; a separate control sets the angle. |
| Goals | Done | Judged by the pitch geometry, with a sound. |
| Collecting | Done | Sticks, stones, cones, wood; 281 pickups in view. |
| Rock jumping | Done | Points for clearing a boulder. |

## Building

| Part | State | Notes |
|---|---|---|
| Eight house parts | Done | Wall, door wall, window wall, floor, roof, roof peak, stairs, post. |
| Placement preview | Done | Ghost, ground tile, and outlines on occupied neighbours. |
| Levelling | Done | The first piece sets the datum; the rest follow it, so a house does not lean downhill. |
| Storeys | Done | Pieces stack a storey at a time. |
| Removal | Done | Refunds exactly what the piece cost. |
| Palette icons | Done | Drawn as 2D primitives, not letters — see `src/ui/part_icon.gd`. |
| Groves | Done | Planting enough saplings close together is detected and rewarded. |

## Animals

| Part | State | Notes |
|---|---|---|
| Four species | Done | Cat, dog, squirrel, beaver, each with its own silhouette and habitat. |
| Streaming and wandering | Done | Spawned per tile around the player, and removed behind them. |
| Shyness | Done | Squirrels flee, dogs approach; a shy animal must be walked up to slowly. |
| Care for reward | Done | Stroke a cat (2), stick to a dog (3), cone to a squirrel (4), stick to a beaver (5). |
| Cooldowns | Done | Guarded in both `nearest_caring` and `care_for`, so one animal is not an infinite mine. |
| Watering | Done | An animal more than 60 m from the river can be thirsty; a drink pays as much as food. |
| Friends | Done | The first of each species cared for is remembered across saves. |
| Beaver dams | **Not started** | Delivering sticks should build something visible. |

## Economy and vitals

| Part | State | Notes |
|---|---|---|
| Coins | Done | Earned only from animals at present. |
| Shop | Done | Five items with icons, an aligned price column, and affordability dimming. |
| Water bottle (12) | Done | Fills in the shallows automatically; four drinks; waters animals. |
| Axe (20) | **Stub** | Purchasable; felling a tree is not implemented. |
| Lantern (28) | **Stub** | Purchasable; does not light anything. |
| Whistle (34) | **Stub** | Purchasable; does not call animals. |
| Bicycle (60) | **Stub** | Purchasable; cannot be ridden. |
| Energy | Done | Running drains, walking and resting restore. At zero, walking is unaffected. |

## Interface

| Part | State | Notes |
|---|---|---|
| Virtual stick | Done | Native `VirtualJoystick`; deflection sets speed. |
| Camera pad | Done | Drag to orbit. |
| Backpack | Done | Right-hand side, showing counts per item. |
| Minimap | Done | Top left, N/S compass, hide / show / enlarge. |
| Vitals gauge | Done | Energy bar and bottle, no numbers. |
| Three languages | Done | English, French, Russian; every string checked present in all three. |
| Opening tasks | Done | Four steps that hand the valley over, each completed by doing it. |
| World reset | Done | Behind a confirmation, separate from the language control. |
| Sound | Done | 12 sounds synthesised at runtime; no audio files. |

## Not started

Named here so they are not mistaken for oversights: horse, bow and arrow,
swimming pool, playground, café, paths and roads, beaver dams, and everything
under networking (accounts, multiple maps, invitations, voice chat).

See ROADMAP.md for the order these are worth doing in and what each depends on.
