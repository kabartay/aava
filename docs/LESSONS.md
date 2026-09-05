# Lessons

Every bug in this list cost real time, was invisible in the code, and is now
guarded by a check or a lint. They are written down because most of them are
properties of Godot or of this project's shape rather than of any one mistake,
and they will otherwise be made again.

## The catalogue at a glance

Sorted by how much time each cost, worst first. The right-hand column is what
stops it happening again — where that column says "nothing", the bug can still
recur.

| Bug | Symptom it presented as | Now guarded by |
|---|---|---|
| Inverted triangle winding | Terrain invisible from above; looked like generation had failed | Screenshot review |
| Cyclic `class_name` dependency | Import hangs forever, no error | Leaf-script rule; CI import |
| Resources built in `_ready` | Null members, or objects with no mesh — four separate times | `_check_nodes_are_usable_immediately` |
| `.gitignore` `build/` matched `src/build/` | Whole building system absent from the repo while working locally | CI on a clean checkout |
| Untyped array literal | Every inferred variable downstream fails to parse | CI grep lint |
| Control drawn at zero size in a container | Icons blank, never redraw; looks like a broken draw routine | LESSONS + comment in `shop_icon.gd` |
| Positional wiring reached 17 arguments | "Expected at least 17, received 14" instead of the missing name | Named handler dictionary with key check |
| Cooldown checked in the query, not the payout | An animal could be paid for twice | `_check_caring_pays` |
| Mesh separated from its material | Four identical white animals in the capture tool | Material attached in `build_mesh` |
| `tonemap_white = 6.0` | Whole scene four times too dark | Nothing — a value, not a class of bug |
| Objects positioned before entering the tree | Balls 56 m from where they appeared | Screenshot statistics |
| `SpringArm3D` colliding with the player | Camera inside the player's head | `add_excluded_object` |
| Houses built on a slope | Pieces leaning downhill by up to 1.8 m | `nearby_datum`; check for a level row |
| `DEPTH_TEXTURE` removed in 4.7 | Water shader fails to compile | Rewritten to use the river formula |
| `PanelContainer` stretching a child | Map dot became a white sheet | Dot moved into the canvas |
| Map redrew only when asked | Capture showed an empty panel | Map self-drives via `_process` |
| Killing processes by name | Killed the user's running game, twice | Kill capture processes by PID only |
| Duplicated an RNG sequence in two places | Trees found a metre from where they were drawn | One `generate_trees`, two callers |
| Rebuilt every vegetation tile in one frame | Looked exactly like a hang; timed out at four minutes | Rebuilds go through the streaming queue |
| `Vector3.ZERO` used to mean "nothing found" | A tree at the origin would read as no tree | Return `[value, found]` instead |
| Per-frame search over nine tiles | ~400 noise lookups a frame to decide one button | Cached until the player moves a metre |
| `TorusMesh` rotated about Y | Bicycle wheels lay flat like dropped hoops | Rotate about X — a torus lies in XZ |
| Placed props before the world streamed | Hang, because felling searched a half-built forest | Props are placed after `_wait_for_world` |
| `global_position` / `look_at` before entering the tree | Butts and arrows placed at the origin | Build the `Transform3D` directly |
| Aim flattened, then nudged upward | Every arrow flew 1.2 m over the gold | Shoot down the line the player is looking |
| `PackedFloat32Array` as a `const` | "isn't a constant expression" — second time | `Array[float]` |
| Two handlers named `place` | The later key silently replaced building | `_check_every_handler_is_reachable` |
| Pool drawn as a rim on flat ground | A white square painted on the grass | Excavated in the height field |
| Same shape computed in two files | Water and hole would drift apart | Both call `PlaceSpec.excavation` |
| Per-vertex work with no bounding test | ~7.7M square roots per build; looked like a hang | Reject on a box before any `sqrt` |
| Signal arity mismatch in a lambda | An error logged on every single kick | `_check_signals_match_their_handlers` |
| Greeting ran before `structures` existed | Crash, but only on a returning visit | Offline growth exercised in a check |
| Arity check matched signals by bare name | Flagged correct code — two classes both declare `completed` | Accept any declared arity for a name |
| Rebuilt all 361 chunks for a 40 m change | Seconds of visibly missing valley | `rebuild_near`, a handful of chunks |
| A replacement matched inside a lambda | Corrupted a `connect()` into a parse error | Rewrote the block by line, not by text |
| `multiplayer` used before entering the tree | Null access instead of an honest failure | `_ready_to_connect()` guard |
| Sent messages on a connection not yet up | "Built a wall" from a game that never joined | `is_connected_to_anyone()` |
| Buoyancy proportional to depth, uncapped | 24.8 m/s² up — the player launched out of deep water | Capped lift and rise speed |
| Positioned a panel before its size was known | It ran off the bottom of the screen | Measure after the page is built |
| Measured frame time with vsync on | Every number was 120 fps, i.e. the refresh rate | Measure uncapped |
| Source checks matched their own comments | Flagged the sentence explaining the rule — twice | `_code_only()` strips comments first |


## Godot 4.7

**A cyclic `class_name` dependency hangs the loader.** Two scripts that declare
global classes and reference each other do not produce an error; the import
simply never finishes. Shared constants belong in a dependency-free leaf script.

**`class_name` does not resolve until the class cache exists.** Global types
live in `.godot/global_script_class_cache.cfg`, which is written by the very
import pass that also parses the scripts. A clean checkout therefore fails its
first import and succeeds on its second. Your own machine never shows this,
because the cache is left over from last time — which is exactly how it reaches
CI unnoticed. CI imports twice.

**Resources built in `_ready` are not built at all** for a node used before the
scene tree starts processing. The pickups had no meshes, and every candidate
failed in silence. Build resources in `_init`.

**GDScript cannot infer a type from an untyped array literal.** `for x in [1.0,
2.0]` makes every `var y := x * 2` a parse error. The same trap wears other
hats: `Array.max()` returns a Variant, and `event.pressed` on a base
`InputEvent` does too. CI greps for the literal form.

**`DEPTH_TEXTURE` was removed** in favour of a `hint_depth_texture` uniform. The
Mobile renderer cannot be relied on for depth or screen reads at all, so a water
shader that needs them only works on desktop — useless for a game whose target
is a tablet.

**Triangle winding for a terrain grid is `[a, b, c, b, d, c]`.** The mirror
order makes terrain invisible from above, which looks exactly like geometry that
was never built. The scene report — 361 chunks, 241,664 triangles, camera aimed
correctly — is what separated those two.

**`Environment.tonemap_white` is an exposure control in disguise.** At 6.0 it
darkens a scene roughly fourfold. AGX holds bright outdoor scenes together
better than ACES.

**`PanelContainer` stretches every direct child to fill it.** A small marker
added to one becomes a sheet over the whole panel.

**`TextureRect` draws its texture at the texture's own size** unless
`expand_mode` says otherwise, so a 75-pixel map sits in the corner of a
190-pixel panel.

**`set_anchors_preset()` leaves a code-created Control at zero size.** Use
`set_anchors_and_offsets_preset()`.

**`pointing/emulate_mouse_from_touch` defaults to true** and fires a synthetic
mouse click *before* the real touch, so every tap arrives twice.

**Godot 4.7 ships a native `VirtualJoystick`.** Writing one is unnecessary, and
`class_name VirtualJoystick` now collides with it.

**`CharacterBody3D.floor_snap_length` must be around 0.5** on rolling terrain.
At the 0.1 default, a run across the valley leaves the floor for a frame dozens
of times a minute — a stutter you feel and cannot see in a screenshot.

**`SpringArm3D` collides with the player it is attached to** unless the body is
excluded, collapsing the camera into the character's head.

**MultiMesh has no per-instance culling**, and `transform_format` defaults to
2D. Vegetation must be chunked into tiles, and the format set before
`instance_count`.

**Applying an impulse to a body the physics server has not stepped does
nothing.** Setting `linear_velocity` is both reliable and the truthful model for
a kick, which replaces motion rather than adding to it.

## Android

**`rendering/textures/vram_compression/import_etc2_astc` must be on** or the
export aborts.

**`/usr/bin/java` on macOS is a stub** whose only job is to tell you to install
Java. `java -version` succeeding proves nothing.

## Git

**Unanchored ignore patterns match at every level.** A `build/` line also
matched `src/build/`, and the entire building system stayed out of the commit
that claimed to add it. The game ran perfectly locally, because locally the
files exist; CI was the first machine to see the tree as it had really been
pushed. Anchor build-output patterns as `/build/`.

## This project

**A tool that builds the game differently from the game photographs a different
game.** The screenshot tool has twice shown something the player would never
see: once with build mode inert, once with an empty map. Shared wiring is the
fix, and every control added there forces both call sites to agree.

**Measure before believing a screenshot.** Balls appeared 56 m from where they
were; footballs looked like blackberries; a valley looked flat and was. In each
case the picture was ambiguous and one printed number was decisive.

**Build resources in `_init`, not `_ready`.** `add_child()` does not run
`_ready` — the tree does, on its next pass. Any caller that adds a node and
uses it on the following line finds whatever `_ready` was going to build still
null. This has now cost four bugs: pickups with no mesh, footballs placed 56 m
away, a build ghost that would not appear, and the ground tile and neighbour
outlines going missing entirely. If a node can be used immediately, it must be
ready immediately.

**A `Control` inside a container has zero size when `_draw` first runs.**
Icons drawn against `size` produced nothing and were never redrawn, which looks
identical to a broken drawing routine. Draw against `custom_minimum_size`, which
the caller sets up front. Connecting `resized` to `queue_redraw` seems like the
obvious fix and is not: it makes redraw and relayout trigger each other and
hangs the process outright.

**Ship the material with the mesh.** `build_mesh()` returned geometry whose
colours live entirely in vertex data, and the one place that knew to set
`vertex_color_use_as_albedo` was the streaming system. The screenshot tool
attached the same meshes and got four identical white animals. A mesh that only
looks right under a particular material should carry that material.

**Positional arguments stop scaling at about a dozen.** Shared wiring reached
seventeen parameters, at which point adding a control meant counting commas at
three call sites and a mistake surfaced as "expected at least 17, received 14"
rather than as the name of the thing forgotten. A dictionary of named handlers,
checked against a list of expected keys, reports the missing one by name.

**Size and colour alone do not distinguish creatures.** Four animals at
different scales and tints read on screen as one rounded lump repeated. What
separated them was silhouette: body length and height per species, a neck that
lifts the head clear of the shoulders, and a tail placed outside the body rather
than inside it.

**A shop of words excludes the child most likely to be saving up.** Five text
rows are a reading exercise. Icons carry the meaning, a fixed price column lets
prices be compared down the list, and a coin beside the number says what is
being asked for.

**A generated world needs one generator, not two.** Trees are `MultiMesh`
instances computed from the seed, so felling one meant recording an exception
that the generator consults. The search for "which tree is near the player" was
written as a second replay of the same sequence — and consumed a different
number of random draws than the tile did, so it found trees a metre from where
they were drawn. There is now one `generate_trees`, called both by the tile that
draws the forest and by the axe that searches it. Where a sequence of random
draws is the contract, that contract can only live in one place.

**Every candidate must consume the same draws, kept or not.** The first version
skipped the scale and rotation draws for a rejected tree, so removing one tree
shifted every tree generated after it — felling one tree moved the whole forest.
Reject after drawing, never before.

**Rebuilding everything at once is indistinguishable from a hang.** Felling a
tree first called a `rebuild_all` that rebuilt every loaded tile synchronously:
dozens of tiles of forty-six candidates each, plus grass, in one frame. The
streaming queue already spreads that work over frames, and the fix was to put
the rebuild through it rather than around it.

**A dictionary of named handlers hides a duplicate key.** Replacing seventeen
positional arguments with a dictionary fixed the counting problem and introduced
a quieter one: adding a `place` handler for the playground silently replaced the
`place` handler that put down building pieces, because a repeated key overwrites
rather than erroring. Building would simply have stopped working. There is now a
check that every handler name is distinct and that each one is actually
connected to a signal.

**Anything that shapes the ground belongs in the height field.** The pool was
first built as a rim and four walls standing on levelled grass, which rendered
as a white square painted on a lawn — there was no hole. Digging it inside
`height_at` means the terrain mesh, the collision heightmap, the grass and the
pickups all agree there is a hollow there, for the same reason the football
pitch is levelled there rather than by a node that draws a pitch.

**Two formulas for one shape will drift.** The depth of the pool decided where
the terrain was cut away *and* how deep the water was for swimming. Written
twice, they would eventually disagree and a child would float above the floor or
stand in the water. Both now call one `PlaceSpec.excavation`, and a check
compares them across the whole pool.

**Anything asked per vertex needs a bounding test before it does any real
work.** `Paths.influence` walked five line segments taking a square root each,
and was called for every terrain vertex, every grass tuft and every tree
candidate — several times over, because `height_at` is called repeatedly for
normals and steepness. That came to roughly seven million square roots per world
build, and the screenshot tool timed out after five minutes on what had been a
five-second job. Two subtractions and two comparisons against a box around the
camp reject almost every point in the world before the first `sqrt`, and the
build went back to five seconds.

**A lambda connected with the wrong number of arguments fails silently at
connect time and loudly at every emission.** `kicked(strength, loft)` was
connected to a lambda taking one argument, which logged an error on every kick
for the life of the project. The signal turned out to be entirely unused, so it
was deleted rather than repaired — but a check now compares every inline
handler's arity against its signal's, across all 53 of them.

**A code path that only runs on the second visit will not fail on the first.**
The arrival greeting was called at the top of `_ready`, before `structures`
existed, and ages saplings by the time the game was closed. A fresh world
returns early from that function, so every test run and every screenshot passed;
it crashed the first time a child came back to a saved valley — the one case the
feature exists for. The check now builds a sapling and ages it.

**A lint that matches on names alone will flag correct code.** The signal-arity
check looked signals up by bare name, and both `Tasks` and `Today` declare a
`completed` — with different signatures, entirely legitimately. The check failed
the build on code that was right. It now collects every arity a name is declared
with and only complains when a handler matches none of them. A check that cries
wolf gets disabled, which is worse than not having it.

**Rebuild what changed, not everything.** A finished dam alters about forty
metres of river, and the first version threw away all 361 terrain chunks and
streamed them back a few per frame — seconds during which the valley was
visibly missing, and long enough that the screenshot tool timed out. Rebuilding
only the chunks within the pond's reach took it to under a second.

**Text replacement is not refactoring.** Adding `session.report_dam_stick(site)`
after `world.dams.deliver(site)` matched twice — once at the call site it was
meant for, and once *inside a lambda* that happened to contain the same line,
turning a `connect()` into a parse error two hundred lines from where the edit
was aimed. For anything structural, replace by line range and read the result
back, or write a named method instead of a multi-line lambda.

**The MultiplayerAPI belongs to the tree, not to the node.** `multiplayer` is
null until a node is actually inside the scene tree, and `add_child` does not
put it there — the tree does, on its next pass. Calling `host()` from
`_initialize` produced a null access rather than a failure a child could
understand. This is the same lifecycle trap as `_ready` versus `_init`, now for
the fifth time, and it is worth stating as a rule: *nothing that a node needs on
the very next line may depend on the tree having processed it.*

**"Connected" and "trying to connect" are different states.** A guest that has
called `join()` is networked, but its connection may still be in flight or may
have already failed. Sending on it fails silently, so a headless test cheerfully
reported building a wall in a valley it had never reached. Every send now checks
the peer's actual connection status, not merely that a session exists.

**A force proportional to a distance needs a ceiling.** Buoyancy was
`BUOYANCY * (depth - SWIM_DEPTH)`, which is right in a swimming pool and wrong
in a river: the river reaches 3.8 m, which came to 24.8 m/s² upward — more than
gravity. A child who waded into a deep stretch was accelerated to the surface
and then kept all that velocity as they broke it, because the moment they were
no longer afloat the water stopped damping them. They flew. The fix is two
ceilings: one on how far down the force keeps growing, and one on how fast
anyone may rise while in water at all.

**An address is a design problem, not a plumbing one.** `192.168.1.161` is
fifteen characters of dots and digits — a six-year-old cannot read it out and a
ten-year-old will mistype it. But two devices on one family network differ only
in the last number, so the screen shows *one number* and asks for *one number*,
tapped on keys the size of a thumb. There is no text entry on that screen at
all, which is also the cheapest way to be sure nothing arrives that has to be
sanitised before another child sees it.

**A frame-time measurement with vsync on measures the monitor.** The first
mobile-renderer benchmark reported a confident 8.34 ms mean — which is 120 fps,
which is the refresh rate, which is what it would have reported for any scene at
all. Uncapped, the same scene ran at 2.51 ms. Turn vsync off and set
`Engine.max_fps = 0` before believing a number.

**Draw calls are the tablet budget, not triangles.** The terrain is one call per
chunk and the ring radius squares, so radius 9 is 361 calls a frame before
anything else is drawn. Making the outermost ring four times coarser cut the
median frame from 2.51 ms to 1.50 ms and removed 18,432 triangles for nothing
visible — the horizon was checked in a screenshot afterwards and holds up. There
is now a check that fails the build if the count passes 400.

**A check that reads source must read the code, not the comments.** The archery
check tripped on the word "animals" in the sentence saying arrows must never
reach one; the voice check tripped on "FileAccess" in the sentence saying voice
must never use it. Both times the comment explaining the rule was the thing that
broke it. The first was worked around by rewording, which was the wrong fix and
left the trap set — the second made it a pattern. `_code_only()` now strips
whole-line comments before any of these checks run.
