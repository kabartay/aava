# Roadmap

What is worth building next, in what order, and why. Ordered by value to the
three children the game is for — ten, six, and two — rather than by how
interesting the problem is.

Last updated: 2026-09-04.

## The principle behind the ordering

Two things decide the order. First, does it close a loop that is currently open?
A purchasable item that does nothing is a broken promise, and there are four of
them in the shop right now. Second, does it give a reason to come back tomorrow?
The valley is pleasant to be in and has almost no memory of yesterday.

## 1. Honour what the shop already sells

Four of the five items are stubs. A child who saves 60 coins for a bicycle and
finds it does nothing has been lied to by the game, and that is worse than the
bicycle never having been listed.

| Item | What it needs | Rough size |
|---|---|---|
| ~~Axe~~ | **Done.** Fells a tree for 4 wood and leaves a stump; the felling is saved, so it stays felled. | — |
| ~~Bicycle~~ | **Done**, together with the horse — one mounted state serving both. | — |
| Lantern | A light that follows the player, and a reason for dark — either a night in the day cycle or a cave. | Medium, larger if it needs a night |
| ~~Whistle~~ | **Done.** Calls every animal within 46 m for six seconds, shy ones included. | — |
| ~~Lantern~~ | **Done**, together with a night worth carrying it through. | — |

**The shop is now honest** — every item does what it says. That was the point of
starting here.

## 2. A reason to return

**Mostly done.** The journal counts what was done rather than what is owned, and
the valley greets a returning child with the most notable thing from last time.
Saplings age while the game is closed, so trees really have grown.

**Done.** One task a day, chosen as a pure function of the calendar day so that
every child on a shared map is offered the same one and they can help each other
with it. Deliberately small: a child who misses three days comes back to one
thing, not a backlog, and ignoring it entirely costs nothing.

## 3. Riding

**Done.** The horse waits near the spawn and fords the river; the bicycle is
faster on the flat and refuses hills and water. One mounted state serves both.

Still worth doing: the mount is a mesh that hides while ridden rather than an
animated thing that carries the player. A horse that visibly moves under the
child would be a real improvement, and is the natural next step here.

## 4. The bow

**Done.** Three straw butts at three distances near the camp; hold to draw,
release to loose. Gold, red and white are worth 5, 3 and 1.

No hunting, and it is enforced rather than intended: the bow tests arrows
against the painted faces and the ground and against nothing else, and a check
reads the source file to keep any future edit from quietly adding a third thing
an arrow can reach.

## 5. Places worth walking to

**Done.** Playground, pool and café stand around the camp, spread far enough
apart that going between them means crossing the valley.

Swimming came with the pool and fixed the river, which had been a wall: walking
in meant sinking to the bed and trudging along the bottom. It is deliberately
forgiving — no drowning, no stamina, and buoyancy that pushes a child back to
the surface. Slower than walking, so it reads as crossing something rather than
as a shortcut.

Both rides now carry the child: the swing sweeps them through its arc, and
stepping onto the top of the slide takes them down it with no button — a child
who climbed the ladder has already said what they want. Both end on their own,
so nobody can be stuck on a ride.

## 6. Paths and roads

**Paths done.** Five routes are worn between the camp, playground, pool, café
and the archery butts, including one that avoids the camp so it is not the only
hub. They live in the height field like the pitch and the pool, so the terrain,
the collision, the grass and the trees all agree they are there: nothing grows
on a path, and the ground is compacted 9 cm rather than trenched.

Still to do here: a road — something wider and more deliberate than a worn
route, connecting the valley to somewhere off the map. That is scenery with a
promise in it, and worth doing when there is something at the other end.

## 7. Beaver dams

**Done.** Eight sticks delivered to one of two sites and the beavers wall the
river; the pond behind it is still there tomorrow.

The pond is made by raising the riverbed rather than the water, because the
water surface is a single flat plane across the whole world and cannot be
lifted locally. Filling the trench gives a child exactly what they expect —
still water, three times as wide as the river, deep enough to swim in — and
every other system already agrees about where the ground is.

This is the only thing in the game that edits the height field after
generation, so it is also the only thing that has to ask for terrain to be
rebuilt. Only the chunks near the dam, not all 361.

## 8. Networking

The largest item by a wide margin, and worth being honest about: accounts,
several maps, invitations, and voice chat between children is not a feature, it
is a second project. Sketch of the order it would go in:

1. **Local profiles** — several named saves on one device. Small, and useful
   immediately even without networking.
2. **A shared world on a LAN** — one device hosts, others join. Godot's
   high-level multiplayer handles this; the hard part is deciding what is
   authoritative. The height field is a pure function of the seed, so terrain
   costs nothing to share; structures and animals must be reconciled.
3. **Invitations and several maps** — each map its own seed and save.
4. **Voice** — the hardest, and the part with real safety implications, since
   the children are young. Push-to-talk between known devices only.

Do not start this until the single-player valley is somewhere they want to be.
A shared empty room is still empty.

## Things worth doing that were not asked for

- **A photograph** — let a child keep a picture of something he built. Children
  show people their work; the game currently offers no way to.
- **Naming things** — a house, a favourite animal, a place on the map. Naming is
  how a place becomes yours.
- **Weather** — rain that pools, a wind that moves the grass. Cheap given the
  vertex-colour pipeline, and it makes returning feel different from leaving.
- **A gentler control for the two-year-old** — the stick is beyond him. Tapping
  a spot to walk there would let him play the same game as his brothers.

## Known debt

- `main.gd` is doing too much: process loop, save format, and every handler.
  Worth splitting once the handler count grows again.
- The capture tool duplicates a little of the game's own setup despite shared
  wiring. Each divergence has produced a screenshot of a game nobody plays.
- Animals are `Dictionary` records rather than a typed class. This is fine at
  four species and will not be at ten.
- No performance measurement on real Android hardware yet. Everything so far is
  an M3 Max at 1280×720, which proves very little about a tablet.
