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
| Beaver dams | Done | Eight sticks at a site and the beavers wall the river; the pond behind is still there tomorrow and deep enough to swim in. |
| Whistle response | Done | A called animal comes at nearly twice its usual speed. |

## Economy and vitals

| Part | State | Notes |
|---|---|---|
| Coins | Done | Earned only from animals at present. |
| Shop | Done | Five items with icons, an aligned price column, and affordability dimming. |
| Water bottle (12) | Done | Fills in the shallows automatically; four drinks; waters animals. |
| Axe (20) | Done | Fells a tree for 4 wood, leaving a stump. The felling is saved. |
| Lantern (28) | Done | Lights a 15 m circle at night. Lit automatically — there is no interesting decision in "would you like to see?". |
| Whistle (34) | Done | Calls every animal within 46 m for six seconds, shy ones included. |
| Bicycle (60) | Done | Rideable, faster than the horse on the flat, refuses hills and water. Appears at camp when bought. |
| Energy | Done | Running drains, walking and resting restore. At zero, walking is unaffected. |

## Night and the bow

| Part | State | Notes |
|---|---|---|
| Real night | Done | Was a permanent orange twilight; now genuinely dark, lit by a moon so the valley keeps its shape. |
| Lantern | Done | A warm 15 m circle. What is outside the circle is worth walking towards. |
| Archery range | Done | Three butts at three distances, gold/red/white worth 5/3/1. |
| Bow | Done | Held to draw, released to loose — the same gesture as the kick. |
| No hunting | Done, enforced | The bow tests arrows against target faces and the ground and nothing else. A check reads the source to keep it that way. |

## Places worth walking to

| Part | State | Notes |
|---|---|---|
| Swimming | Done | The river was a wall before this. Forgiving by design: no drowning, no stamina, buoyancy pushes a child back up. |
| Swimming pool | Done | Dug into the height field, so the hole and the water are the same shape by construction. Shelves at the edge. |
| Playground | Done | The swing carries a child through its arc; stepping onto the top of the slide rides it down. Both end on their own. |
| Café | Done | 3 coins for a meal that restores 55% of the energy bar — closes the energy loop from the other end. |
| Levelled ground | Done | Playground, pool and café are flat by construction, like the football pitch. |
| Paths | Done | Five routes worn between camp, playground, pool, café and the butts. Bare earth, no grass through them, sunk 9 cm. |

## Riding

| Part | State | Notes |
|---|---|---|
| Horse | Done | Waits near the spawn. Fords the river, climbs what a bicycle cannot. |
| Bicycle | Done | Faster on the flat; refuses steep ground and deep water. |
| Mounted state | Done | The mount follows the player rather than carrying them — a body parented to a moving node inherits its rotation. |
| Camera lift | Done | Eased, not snapped: mounting feels like rising rather than teleporting. |
| Put down, not stranded | Done | Riding onto ground the mount cannot take dismounts the child rather than trapping them. |

## Coming back

| Part | State | Notes |
|---|---|---|
| Journal | Done | Counts what was done, not what is owned: built, cared for, goals, rocks, planted, coins. |
| Arrival greeting | Done | One line naming the most notable thing from last visit, weighted so one house outranks forty rocks. |
| Offline growth | Done | Saplings age by the time the game was closed, capped at 15 minutes so a fortnight away does not skip the change. |
| One thing a day | Done | A single task, a pure function of the calendar day, so everyone on a map gets the same one. No backlog, no penalty for missing it. |

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

## Players, maps and worlds

| Part | State | Notes |
|---|---|---|
| Player profiles | Done | Each child a name and their own progress. Latin and Cyrillic names. |
| Map templates | Done | A map is a seed — the same valley for everybody, like a Call of Duty map. |
| World instances | Done | A world is one copy of a map. Two children can each have their own copy of the same valley. |
| Invitations | Done | Being invited puts you in *that* copy — you walk into your friend's house, not a picture of it. |
| Shared vs private state | Done | Buildings, felled trees and dams belong to the world; bag, coins and journal to the child. |
| Migration | Done | A valley built before profiles existed becomes the first world rather than being abandoned. |
| Networking | **Not started** | The file layout is the shape a network needs; the transport is not written. |
| Voice chat | **Not started** | The hardest part, with real safety implications. See ROADMAP.md. |

## Not started

Named here so they are not mistaken for oversights: a road leading off the map,
network transport, and voice chat.

See ROADMAP.md for the order these are worth doing in and what each depends on.
