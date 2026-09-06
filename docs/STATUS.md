# Status

What exists in the game today, and how finished each part is. Written so that
someone returning after a month knows what they can play and what they cannot.

Last updated: 2026-09-06.

## Legend

- **Done** — implemented, covered by checks, seen working in a screenshot or
  on the tablet.
- **Partial** — usable, but a stated part of it is missing.
- **Stub** — the object exists; the behaviour behind it does not.

## The world

| Part | State | Notes |
|---|---|---|
| Terrain | Done | Procedural from one integer seed, streamed in 64 m chunks with LOD rings out to a 576 m radius. |
| Height field | Done | A pure `height_at(x, z)`. Every other system asks it rather than keeping its own idea of the ground. |
| Mountains | Done | Rise on a curve, not a wall: ~2° near the valley, steepening to a real 33–35° flank well beyond it. Start far enough out that the walkable kilometre stays a valley rather than a foothill. |
| Inner valley shape | Done | Hills inside the valley itself, so the playable ground has relief of its own rather than being flat with peaks on the horizon. |
| River | Done | A meander from two sine waves, longer than the first version; carves its own bed through the height field. Fordable on a horse, swimmable on foot. |
| Lakes | Done | Two carved basins away from the river, shelving at the edge like a beach rather than a step. A second kind of water to swim in, not just cross. |
| Water surface | Done | Custom shader. Does not use `DEPTH_TEXTURE`, which 4.7 removed. |
| Sky and light | Done | Procedural sky, AGX tonemapping, depth fog, a full day/night cycle rather than a fixed time of day. |
| Snow line | Done | Blends in above the treeline by height and steepness, so peaks read as peaks rather than the same green as the valley floor. |
| Paths | Done | Worn routes between camp, playground, pool, café and the archery butts. Read purely by colour and no grass growth — an earlier sunk version cost more than it was worth to see. |
| Vegetation | Done | Plants per view via `MultiMeshInstance3D`, tiled so culling works; density falls off with altitude and stops at the treeline. |
| Boulders | Done | The jumpable ones award points. |
| Birds | Done | Ambient, drawn from the same vertex-colour material as everything else. |

## Play

| Part | State | Notes |
|---|---|---|
| Walking, running, jumping | Done | `CharacterBody3D`, coyote time, jump buffer, floor snapping. Falling is now faster than rising, so a jump reads as a jump rather than a slow float back down. |
| Camera | Done | `SpringArm3D` with a top-level camera and exponential smoothing; excludes the player's own capsule; snaps back quickly when a wall pushes it in but still eases pulling back out. |
| Zoom | Done | Distance only — the aim point does not move, so zooming never disorients. |
| Minimap | Done | Three sizes, cycled by tapping: small, large, and a full view of the whole valley with every destination as a coloured dot. |
| Football pitch | Done | Levelled inside the height field itself, so the ground is flat by construction rather than by flattening afterwards. |
| Balls and kicking | Done | `RigidBody3D` with continuous collision detection. Kick sets velocity directly. |
| Kick power and loft | Done | Held button charges strength; a separate control sets the angle. |
| Goals | Done | Judged by the pitch geometry, with a sound. |
| Collecting | Done | Sticks, stones, reeds, seeds and cones, streamed and gathered by walking over them. |
| Rock jumping | Done | Points for clearing a boulder. |

## Building

| Part | State | Notes |
|---|---|---|
| Nine house parts | Done | Wall, door wall, window wall, floor, roof, roof peak, stairs, post, and a **bed**. |
| Solid walls | Done | Walls, doors, windows and posts have real collision, with a door's opening left genuinely walkable rather than one solid slab across the panel — a wall you could walk straight through, found by a fresh look after everything else here. |
| Placement preview | Done | Ghost, ground tile, and outlines on occupied neighbours. |
| Levelling | Done | The first piece sets the datum; the rest follow it, so a house does not lean downhill. |
| Storeys | Done | Pieces stack a storey at a time. |
| Removal | Done | Refunds exactly what the piece cost. |
| Palette icons | Done | Drawn as 2D primitives, not letters. Every house part is checked to have one, after the bed shipped without one for a while. |
| Groves | Done | Planting enough saplings close together is detected and rewarded. |
| Two tree species | Done | A round-crowned sapling and a taller fir, grown from a seed or a cone; the fir is worth more and grows more slowly. |
| Trees are capital | Done | Felling a tree costs exactly what growing one of its kind would have paid — an afternoon with an axe used to be pure profit, since felling refunded nothing. |
| Campfires | Done | Burn real logs (up to six), warm the ground nearby, and rest a child beside one nearly two and a half times faster. Persist across saves at the position built. |
| Sleep | Done | A bed is only useful after dark: sleeping sets the time to dawn and restores full energy. Trying at noon is refused, kindly. |

## Animals

| Part | State | Notes |
|---|---|---|
| Four species | Done | Cat, dog, squirrel, beaver, each with its own silhouette and habitat. |
| Streaming and wandering | Done | Spawned per tile around the player, and removed behind them. Footing is clamped to a shallow wade near water, so a beaver at the river's edge no longer stands on the bed of the river with the surface over its head. |
| Shyness | Done | Squirrels flee, dogs approach; a shy animal must be walked up to slowly. |
| Care for reward | Done | Stroke a cat, give a stick to a dog or a beaver, a cone to a squirrel. Beavers pay the most, since they are the hardest to reach. |
| Cooldowns | Done | Guarded in both `nearest_caring` and `care_for`, so one animal is not an infinite mine. |
| Watering | Done | An animal far from the river can be thirsty; a drink pays as much as food. |
| Friends | Done | The first of each species cared for is remembered across saves. |
| Beaver dams | Done | Sticks at a site and the beavers wall the river; the pond behind is still there tomorrow. |
| Whistle response | Done | A called animal comes at nearly twice its usual speed. |
| Voices | Done | Each kind speaks on its own terms — a bark, a chatter, a grunt — as a single event from where the animal actually is, at long, jittered intervals. A cat purrs only when it is actually stroked, never on its own. |

## Economy and vitals

| Part | State | Notes |
|---|---|---|
| Coins | Done | Earned from animals and from what trees pay when they mature or are felled. |
| Shop | Done | Five items with icons, an aligned price column, and affordability dimming. |
| Water bottle | Done | Fills in the shallows automatically; several drinks; waters animals. |
| Axe | Done | Fells a tree for its wood, leaving a stump; wood feeds a campfire. The felling is saved. |
| Lantern | Done | Lights a circle at night. Lit automatically — there is no interesting decision in "would you like to see?". |
| Whistle | Done | Calls every animal within earshot for a few seconds, shy ones included. |
| Bicycle | Done | Rideable, faster than the horse on the flat, refuses hills and water. Appears at camp when bought. |
| Energy | Done | Running drains, walking and resting restore; resting near a lit campfire restores much faster. At zero, walking is unaffected. |

## Night and the bow

| Part | State | Notes |
|---|---|---|
| Real night | Done | A full day/night cycle, lit by a moon so the valley keeps its shape after dark. |
| Lantern | Done | A warm circle of light. What is outside it is worth walking towards. |
| Archery range | Done | Three butts at three distances, worth different amounts. |
| Bow | Done | Held to draw, released to loose — the same gesture as the kick. |
| No hunting | Done, enforced | The bow tests arrows against target faces and the ground and nothing else. A check reads the source to keep it that way. |

## Places worth walking to

| Part | State | Notes |
|---|---|---|
| Swimming | Done | Forgiving by design: no drowning, buoyancy pushes a child back up, capped so nobody launches out of deep water. A small hysteresis band now keeps a stationary swimmer from flickering between walking and swimming physics at the exact threshold depth. |
| Swimming pool | Done | Dug into the height field, so the hole and the water are the same shape by construction. |
| Playground | Done | The swing carries a child through its arc; stepping onto the top of the slide rides it down. Both end on their own. |
| Café | Done | A meal restores a large fraction of the energy bar — closes the energy loop from the other end. |
| Levelled ground | Done | Playground, pool and café are flat by construction, like the football pitch. |
| Spread out | Done | Destinations sit several hundred metres apart around the camp, so getting to one means crossing the valley rather than a courtyard. |
| Whole-valley map | Done | Double-tap (third tap) the minimap for a view of the entire valley, with a coloured dot for every destination — a six-year-old cannot read a label, so the colour has to carry it. |

## Riding

| Part | State | Notes |
|---|---|---|
| Horse | Done | Waits near the spawn. Fords the river, climbs what a bicycle cannot, and now turns at its own slower rate rather than exactly as fast as a child on foot. |
| Bicycle | Done | Faster on the flat; refuses steep ground and deep water; its own turn rate too. |
| Mounted state | Done | The mount follows the player rather than carrying them — a body parented to a moving node inherits its rotation. |
| Camera lift | Done | Eased, not snapped: mounting feels like rising rather than teleporting. |
| Put down, not stranded | Done | Riding onto ground the mount cannot take dismounts the child rather than trapping them. |

## Sound

| Part | State | Notes |
|---|---|---|
| Everything synthesised | Done | No audio files anywhere. Sound effects and the whole ambient bed are generated `AudioStreamWAV` data at load. |
| Ambient wind, water, birds | Done | Wind is two damped noise bands gusting on non-commensurate periods rather than one hiss; water is a steady sheet with burbles welling through it; birds carry a second harmonic and vibrato rather than a pure sine, and are quieter at night. |
| Leaf rustle | Done | Its own voice, scaled by local forest density, so it no longer follows a child into a treeless meadow. |
| Weather drift | Done | Wind and leaf strength wander slowly over minutes rather than holding one constant level. |
| Animal voices | Done | Event-based, not ambient — see Animals above. |

## Coming back

| Part | State | Notes |
|---|---|---|
| Journal | Done | Counts what was done, not what is owned: built, cared for, goals, rocks, planted, coins. |
| Arrival greeting | Done | One line naming the most notable thing from last visit, weighted so one house outranks forty rocks. |
| Offline growth | Done | Saplings age by the time the game was closed, capped so a fortnight away does not skip the change. |
| One thing a day | Done | A single task, a pure function of the calendar day, so everyone on a map gets the same one. No backlog, no penalty for missing it. |
| Sleep resets the day | Done | Sleeping through the night, not just the clock, is now the natural way a session ends. |

## Interface

| Part | State | Notes |
|---|---|---|
| Virtual stick | Done | Native `VirtualJoystick`; deflection sets speed. |
| Camera pad | Done | Drag to orbit. |
| Backpack | Done | Right-hand side, showing counts per item. |
| Minimap | Done | Three sizes; the largest shows the whole valley. |
| Vitals gauge | Done | Energy bar and bottle, no numbers. |
| Three languages | Done | English, French, Russian; every string checked present in all three. |
| Opening tasks | Done | Steps that hand the valley over, each completed by doing it. |
| World reset | Done | Behind a five-second hold, separate from the language control. |
| Context buttons | Done | Visit, dam, fire and sleep no longer share one screen position — a bed and a campfire are both ordinary house pieces and can be in reach at once, which the old shared-position code could not show. |

## Players, maps and worlds

| Part | State | Notes |
|---|---|---|
| Player profiles | Done | Each child a name and their own progress. Latin and Cyrillic names. |
| Map templates | Done | A map is a seed — the same valley for everybody, like a Call of Duty map. |
| World instances | Done | A world is one copy of a map. Two children can each have their own copy of the same valley. |
| Invitations | Done | Being invited puts you in *that* copy — you walk into your friend's house, not a picture of it. |
| Shared vs private state | Done | Buildings, felled trees, campfires and dams belong to the world; bag, coins and journal belong to the child. |
| Migration | Done | A valley built before profiles existed becomes the first world rather than being abandoned. |
| Networking | Done (LAN) | One device hosts, others join on the family network. Verified across two processes on one machine; not yet tried between two physical devices over real Wi-Fi. |
| Play-together screen | Done | The host shows one big number; the guest taps it on a keypad. No text entry anywhere. |
| Visitors | Done | Other children drawn where they stand, with their name above them, eased between updates. |
| Voice chat | Done | Push-to-talk only; the microphone is stopped, not merely muted, between presses. Only to children already in the valley. Never recorded. |

## Android

| Part | State | Notes |
|---|---|---|
| APK builds | Done | arm64. See ANDROID.md for the toolchain. |
| Mobile renderer | Done | Verified on the tablet; terrain, water, animals and UI all correct. |
| Draw-call budget | Done | Checked against a ceiling in CI. |
| Tested on a real tablet | Done | Found and fixed on-device: the player launching into the sky while swimming, the game locked to portrait, a horse vanishing when mounted, mountains barely visible, night too dark, the minimap compass rotating the wrong way, a progressive stutter from chunk streaming. |
| Frame times, thermals, battery on device | Partial | The tablet runs the game; nothing here has been logged and profiled over a long session yet. |

## Continuous integration

| Part | State | Notes |
|---|---|---|
| CI pipeline | Done | Import, a lint against untyped array literals in a `for` loop, the full check suite, and a debug Android export, on every push. |
| Green | Done | Was silently red for two days on a lint rule too blunt for its own good; fixed by bringing the flagged code into compliance rather than weakening the rule. |

## Not started

Named here so they are not mistaken for oversights: a road leading off the map,
collision on floors, roofs and stairs (so a second storey is not yet something
a child can stand on), and a longer session of frame-time, thermal and battery
measurement on the actual tablet.

See ROADMAP.md for the order these are worth doing in and what each depends on.
