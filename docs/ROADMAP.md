# Roadmap

What is worth building next, in what order, and why. Ordered by value to the
three children the game is for — ten, six, and two — rather than by how
interesting the problem is.

Last updated: 2026-09-06.

## The principle behind the ordering

Two things decide the order. First, does it close a loop that is currently
open — a purchasable item that does nothing, a piece you can build but not
stand behind, a device the game has never actually run on. Second, does it
give a reason to come back tomorrow.

## Everything below this line used to be the roadmap

The shop is honest, the world has a night, riding, a bow, places worth
walking to, paths, beaver dams, and a full networking and voice-chat layer —
all of it shipped, all of it played on the tablet. What follows is what is
left now that the original list is done.

## 1. Multi-storey collision

Walls, doors, windows and posts are solid now — a real fix, since a child
could walk straight through a wall they had just built, and the camera sailed
through it too. Floors, roofs and stairs deliberately were not given
collision alongside them: nothing in the game yet supports actually standing
on an upper storey, and a solid floor with no way onto it only traps a child
underneath it.

This is the natural next building feature: give stairs a real, climbable
collision shape (six steps of roughly 0.4 m each, which is more than a
`CharacterBody3D`'s default step-up unless that is raised to match), then
floors a thin solid slab to stand on. Worth doing together, since a floor
without stairs to reach it is furniture nobody can use.

## 2. A road leading off the map

Every path currently connects places inside the valley. Nothing yet suggests
the valley continues past its edge. A road running to the map's boundary —
wider and more deliberate than a worn route — is scenery with a promise in
it, worth doing once there is something at the other end, even if that
something is only the promise itself for now.

## 3. Longer sessions on the actual tablet

Frame time, thermals and battery have only been checked in short bursts.
Everything measured so far (draw calls, chunk cost, the tablet screenshots
that caught the portrait-lock and the flying-player bugs) proves the game
runs; none of it proves what forty-five minutes in a six-year-old's hands
does to a mid-range tablet's battery or thermal throttling. This needs an
actual long play session with `adb shell dumpsys batterystats` and a
thermal read before and after, not a ratio from a laptop.

## 4. Mountain and valley aesthetics

The mountains rise on a real curve now rather than a wall, and snow blends in
above the treeline — but there is room to push this further towards a real
alpine range (the Alps, the Caucasus): more snow at altitude, sharper ridge
definition, and possibly a second, more dramatic peak silhouette on the
horizon that reads as a destination rather than a backdrop. Purely visual;
worth doing with a screenshot in hand at every step, since a mountain range
is judged by the eye, not by a number.

## Things worth doing that were not asked for

- **A photograph** — let a child keep a picture of something he built.
  Children show people their work; the game currently offers no way to.
- **Naming things** — a house, a favourite animal, a place on the map. Naming
  is how a place becomes yours.
- **Weather** — rain that pools, a wind that moves the grass more visibly.
  Cheap given the vertex-colour pipeline, and it makes returning feel
  different from leaving.
- **A gentler control for the two-year-old** — the stick is beyond him.
  Tapping a spot to walk there would let him play the same game as his
  brothers.

## Known debt

- `main.gd` is 1,096 lines and doing too much: the process loop, the save
  format, and every handler. Worth splitting once the handler count grows
  again.
- `src/ui/hud.gd` is 1,125 lines for the same reason — every on-screen
  control, its layout, and its state, in one file.
- `src/dev/ci_check.gd` is over 3,000 lines. This is the project's whole
  safety net and every line of it earns its keep, but it is long enough now
  that finding one check among the others takes a moment — worth splitting
  by subject (world, building, animals, networking) if it keeps growing.
- The capture tool duplicates a little of the game's own setup despite shared
  wiring. Each divergence has produced a screenshot of a game nobody plays.
- Animals are `Dictionary` records rather than a typed class. This is fine at
  four species and will not be at ten.
- The map/world/player save-path plumbing has been verified end-to-end by a
  scripted probe, but never by two actual devices sharing an invitation over
  a real evening.
