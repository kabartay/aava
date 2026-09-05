# Android

The target device is a tablet. Everything else in this project was measured on
a laptop, which tells you almost nothing about one — so this file records what
the build actually needs and what the measurements actually say.

Last updated: 2026-09-05.

## Building an APK

Godot's Android export needs three things present, and the failure when one is
missing is usually unhelpful.

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$JAVA_HOME/bin:$PATH"
godot --headless --path . --export-debug "Android" build/aava.apk
```

| Needs | Where | Note |
|---|---|---|
| JDK 17 | `/opt/homebrew/opt/openjdk@17` | Not 21 or 26. Godot 4.7 wants 17. |
| Android SDK | `~/Library/Android/sdk` | Build-tools 34 or 36, platform 34+. |
| Export templates | `~/Library/Application Support/Godot/export_templates/4.7.2.stable` | Version must match the editor exactly. |
| Debug keystore | `~/Library/Application Support/Godot/keystores/debug.keystore` | Password `android`, alias `androiddebugkey`. |

**A JDK being installed is not a JDK being on `PATH`.** Homebrew installs into
`/opt/homebrew/opt/` and does not link JDKs by default, so `java -version` fails
while three of them sit on disk. Export the two lines above.

The paths themselves live in the editor settings, not in the project:
`export/android/java_sdk_path` and `export/android/android_sdk_path` in
`~/Library/Application Support/Godot/editor_settings-4.7.tres`. They are per
machine, so a fresh checkout on another computer has to set them again.

## Installing on a tablet

Developer options on, USB debugging on, then:

```sh
~/Library/Android/sdk/platform-tools/adb install -r build/aava.apk
```

`cannot connect to daemon at tcp:5037` at the end of an export is `adb` not
running with no device attached. It is harmless — the APK is already written.

## What the numbers say

Measured on an M3 Max with the mobile renderer, vsync off, at the camp:

| | Before | After |
|---|---|---|
| Median frame | 2.51 ms | **1.50 ms** |
| Mean | 3.20 ms | 2.16 ms |
| 95th percentile | 6.47 ms | 6.68 ms |

The change was making the outermost LOD ring four times coarser — step 4 to
step 16. At two hundred metres a chunk is then eight triangles across, which is
invisible, and it removed 18,432 triangles a frame for nothing given up. The
horizon was checked in a screenshot afterwards: no faceting.

**These numbers are not tablet numbers.** A mid-range tablet GPU is somewhere
between eight and fifteen times slower than this laptop, which puts 1.5 ms at
12–23 ms, or 43–67 fps. That should be comfortable, but it is an estimate from a
ratio and nothing more. The real measurement needs a real device.

## What a tablet actually runs out of

Draw calls, not triangles. The terrain is one call per chunk and the ring radius
squares, so radius 9 is 361 calls a frame before anything else is drawn. That is
the number to watch, and `_check_it_will_run_on_a_tablet` fails the build if it
passes 400.

Collision is worse than drawing: only the two nearest rings have any, because a
`HeightMapShape3D` per chunk across the whole world would cost more than the
rest of the frame together.

Vegetation is 5,875 plants in about 49 `MultiMeshInstance3D` tiles. One node per
plant would be 5,875 draw calls and nothing else would matter.

## Still to check on a real device

Named here so they are not mistaken for done:

- **Frame times on the actual tablet.** Everything above is a ratio.
- **Touch targets.** The buttons are 96 px and the keypad 92 px, which is right
  on a 1280-wide capture, but a tablet's density is different.
- **Thermals.** A laptop at 1.5 ms a frame is idling; a tablet at 20 ms is
  working, and will throttle after ten minutes in a child's hands.
- **Battery.** Related, and the thing a parent notices.
- **The virtual stick under a small thumb.** It was sized against a screenshot,
  not against a six-year-old.
- **Networking over real Wi-Fi**, rather than two processes on one machine.
