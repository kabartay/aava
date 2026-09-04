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
| Axe | Felling a tree: a swing, a fall, and wood into the bag. The tree must not regrow instantly or the forest becomes a mine. | Medium |
| Bicycle | A mounted state with a higher top speed and a wider turning circle, and a camera that pulls back. Reuses the horse work below. | Medium |
| Lantern | A light that follows the player, and a reason for dark — either a night in the day cycle or a cave. | Medium, larger if it needs a night |
| Whistle | Nearby animals path toward the player. Cheap, and it makes the shy squirrel catchable. | Small |

**Do the whistle first.** It is the smallest, and it makes the animals that are
already there better rather than adding anything new.

## 2. A reason to return

The strongest thing missing. The valley remembers what you built and what
animals you befriended, but never says so. A child logging in on a Tuesday
should be met with what he did on Monday.

- Something visible that grew overnight: saplings advancing a stage, a grove
  filling in.
- A short list on opening: what you built, who you fed, how far you walked.
- One thing per day that is only available that day — a particular animal near
  the camp, a spot on the map worth walking to.

This is not large to build and is probably the highest-value item on this page.

## 3. Riding

Asked for directly. A horse that can be mounted, ridden across the valley, and
taken through the river ford.

Depends on: a mounted movement state, which the bicycle also wants. Build the
state once and let both use it.

Watch for: the camera. A mounted camera at walking distance feels claustrophobic;
it needs to pull back and raise its pitch.

## 4. The bow

Asked for directly. Target shooting only — no hunting, and this should be
enforced by the code rather than by convention, since the animals are there to
be cared for.

Needs: a draw-and-release control that reuses the kick charge, an arrow with a
sensible arc, and targets worth hitting. Straw butts near the camp.

## 5. Places worth walking to

The valley is large and evenly interesting, which means nowhere in particular is
worth going. Each of these is a destination.

- **Playground** — swings and a slide that actually move the player. The
  two-year-old's entry point; he cannot manage the stick reliably but can press
  a button and watch something happen.
- **Swimming pool** — needs swimming, which the river currently does not have.
  Doing this properly also fixes the river.
- **Café** — somewhere to spend coins on food that restores energy. Closes the
  energy loop from the other end.

## 6. Paths and roads

Asked for. A path is a strong signal about where to go, which is what the valley
lacks. Worth doing after there are destinations for paths to connect, not
before, or they lead nowhere.

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
