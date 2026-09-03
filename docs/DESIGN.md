# Aava — design

## The problem this design solves

The primary player is ten years old and plays Minecraft, which has fifteen years
of content in it. Anything one developer authors by hand, he will exhaust in
under an hour and then be bored. So authored content cannot be the answer, and
every decision below follows from that.

Three things carry the game instead:

1. **He is the content engine.** Building is not a feature bolted onto an
   adventure; it is the thing that produces the game's content.
2. **The world answers what he builds.** In Minecraft you build and the world
   stays indifferent. Here every structure has a consequence, and consequences
   generate themselves.
3. **His family lives in the world.** His parents and his 2-year-old sibling
   are inhabitants. No studio can produce that, and it costs us nothing.

The third point is the only honest answer to "why not just play Minecraft".

## The loop

```
walk  ->  discover  ->  gather  ->  build  ->  the world wakes up  ->  further
```

The last arrow is the important one, and it must always close:

| You build | The world answers | Which gives you |
| --- | --- | --- |
| Plant saplings | a grove grows over days | nuts, mushrooms, deer, birdsong |
| A feeder | specific birds settle | seeds from biomes you have not reached |
| A pond, a channel | frogs, dragonflies, reeds | reeds are a building material |
| A bridge | inhabitants start crossing | their errands, and their requests |
| A house | someone moves in with a craft | construction you could not do before |

So: **build -> inhabitants -> new materials -> build**. This is a system that
produces content rather than a list of quests that has to be written one by one,
which is the only version of this game a single developer can actually finish.

## Keeping a ten-year-old going

Tools enlarge the world rather than increasing a number. Every one of them is a
new place, not a new stat:

| Tool | Opens |
| --- | --- |
| Axe | deadfall, paths into dense forest |
| Shovel | digging, channelling water, reshaping ground |
| Pick | caves, stone, ore |
| Rope and hook | cliffs, the way into the mountains |
| Raft | the river, the lake, islands |
| Lantern | deep caves, the forest at night |

Each is made from something the world gave you *because* you built something, so
building is never optional decoration.

A **discovery journal** fills in as he finds animals, plants and stones. Each
entry carries something true about the thing found. This is the "learning
something" part of the brief, and it never appears as a test.

## The six-year-old

The same verbs, no reading required, and nothing he can fail.

He sees a glimmer on anything that can be picked up — **his brother does not**.
He carries, places, decorates, feeds animals and names them; a named animal stays
in the world for good and follows him.

One rule is absolute here, learned from a previous attempt that failed: **the
elder needs nothing from the younger.** The younger only ever adds. A first
version of this game made cooperation mandatory — neither brother could finish a
room alone — and it turned out to be coercion rather than a reason to talk. Both
brothers must be able to play alone and enjoy it. Together is a multiplier, never
a lock.

## The family

The 2-year-old is a villager: he toddles after you, laughs, claps when
something is finished. The parents live there too and make small requests. None
of them is a playable mode; they are presence.

**Parent mode**, from a phone: a real errand at home becomes a gift in the world.
Tidy the toys, read ten pages, learn five French words. Not a control system —
another family adventure.

## What this design deliberately does not have

- **No combat.** Nothing in the brief needs it, and it would change the tone the
  whole world is built to carry.
- **No competition between the brothers.** A ten-year-old beating a six-year-old
  ends in tears. They compete with the family's own record instead.
- **No losing.** Time and mistakes cost you a slower day, never a failure screen.
- **No hand-authored quest chains** as the main content, for the reason at the top
  of this document.

## Technical choices

**Godot 4.7 with GDScript.** A world with forests, hills, mountains and animals
is engine-heavy: terrain streaming, level of detail, navigation, animation
blending, instanced vegetation. Godot ships all of it. The alternative considered
seriously was Three.js in the browser, which wins on distribution — a link opens
on any tablet, no store, no paid developer account — but would have meant writing
those subsystems by hand before writing any game. Android is the first target,
where the SDK was already installed; iPad needs a paid Apple account and comes
later.

**Everything is generated from code and data.** No hand-placed scene content.
This is partly a consequence of how the project is written — from a terminal,
without the editor — and partly the only way to get a world large enough. The one
thing placed by hand is placed by the child, and that is the game.

**The look comes from light, not from art.** There are no textures and no
hand-modelled art in the foundation: vertex-coloured terrain, a shader for water,
and a sun with a sky. What separates a warm sunlit valley from a pile of coloured
polygons is the angle of the light, the colour it throws, how far you can see
before air takes over, and how the sky moves across an evening. Free CC0 model
kits (Kenney, Quaternius) fill the world in; the light is what makes it look like
somewhere.
