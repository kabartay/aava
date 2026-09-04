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

Still missing: **one thing per day that is only available that day** — a
particular animal near the camp, a spot on the map worth walking to. This is
what turns "the valley remembers me" into "there is a reason to go today".

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

Still worth doing here: the slide does not actually slide a child down it, and
the swing does not carry them. Both are currently things to watch rather than
things to ride.

## 6. Paths and roads

Asked for, and now unblocked: there are four destinations for paths to connect
(camp, playground, pool, café) plus the pitch and the archery range.

Needs: a road layer in the height field (paths should flatten slightly, as the
pitch does), and a mesh that follows terrain without floating.

## 7. Beaver dams

Deliver sticks, a dam appears across a narrow point, the water behind it rises.
The most interesting of the animal ideas because it changes the world rather
than the score. Also the most work, since it touches the height field and the
water surface.

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
