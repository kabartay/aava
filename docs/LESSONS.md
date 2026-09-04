# Lessons

Every bug in this list cost real time, was invisible in the code, and is now
guarded by a check or a lint. They are written down because most of them are
properties of Godot or of this project's shape rather than of any one mistake,
and they will otherwise be made again.

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
