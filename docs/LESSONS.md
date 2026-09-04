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
