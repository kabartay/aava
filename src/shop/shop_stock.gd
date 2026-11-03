class_name ShopStock
extends RefCounted

## What the shop sells.
##
## ECONOMY NOTES — what earns, what it earns, and why (read before changing a
## number anywhere; a check holds the ordering).
##
## The aim, for children of six to twelve who play a lot: every animal and
## activity worth a visit, nothing worth standing in one spot to repeat, and
## something still to save for after an hour (the quad, 199) and after a week
## (the motorcycle, 299 — and a second one, or the quad as well). Coins stop at
## 9999, which is not a goal, only a ceiling.
##
## Per visit, with the rest the thing needs before it pays again:
##   cat      2 coins, nothing needed, ready again after  40 s
##   dog      3 coins, a stick,                           30 s
##   squirrel 4 coins, a cone (hard to find; it bolts),   25 s
##   beaver   5 coins, a stick (and a walk to the water), 35 s
##   sheep    1 fleece = 2 coins at the shop, shears,    100 s
##   a butt   up to 5 coins, then it rests 150 s (three butts)
##   a tree   3 coins grown (6 for a fir), after 150 s; felling takes it back
##   today's task 8 coins, once a day
##   a goal   no coins: the score is the game
## The sheep used to give three fleeces at four coins every 90 s: twelve coins
## a visit with no cone or stick to find, against a squirrel's four, and a flock
## of a hundred made everything else pointless. A fleece is now worth no more
## than a cat's stroke, which is what an animal that needs nothing should pay;
## the shears (39) still pay for themselves in twenty fleeces, and a rug still
## costs one. The bow used to pay five coins an arrow, as often as an arrow
## could be loosed, with no limit; now a butt pays once and then rests.
##
## Nothing here can be turned into more than it cost. Buying back from the shop
## pays half; a grown tree taken down gives its seed back and takes its coins
## back (one not yet grown has paid none); a ticket not used is returned at the price
## paid; a cafe or a shop of a child's own charges or pays what the valley's does,
## never more; wool put into a rug comes back as wool, not coins.
##
## Every item is bought once and kept forever. There are no consumables and
## nothing to re-buy: a child who has earned a bicycle should own a bicycle, not
## be made to earn it again, and a shop that drains what you saved is a shop
## that teaches you not to save.
##
## Prices are set against what an animal gives, so each one is a countable
## number of good deeds rather than an abstract sum. A squirrel gives four; the
## water bottle costs twelve, which is three squirrels — a walk in the forest.

const BOTTLE := &"bottle"
const AXE := &"axe"
const LANTERN := &"lantern"
const BICYCLE := &"bicycle"
const WHISTLE := &"whistle"
## The dearest thing in the shop by a long way, and deliberately: it is the
## fastest way to cross the valley and the surest way to find it empty when you
## arrive, so it should be the reward for a great many good deeds rather than
## the obvious second purchase.
const MOTORCYCLE := &"motorcycle"
## Between the two machines in price as well as in speed.
const QUAD := &"quad"
## A proper saddle and girth. A horse will carry you bareback up anything it
## can walk up; with a saddle under you it will take ground you would slide
## off, which is what turns the steep shoulders of this valley from walls into
## ways through. The one purchase that makes the map bigger rather than faster.
const SADDLE := &"saddle"
## Shears, for the sheep. A fleece grows back, so this is the one purchase that
## pays for itself over and over — which is the point of it: it turns a walk
## across the meadow into a living rather than a single reward.
const SHEARS := &"shears"
## A bar of chocolate: the one thing here that is used up.
##
## Everything else in this shop is bought once and kept, which is the right
## rule for a bicycle and the wrong one for something to eat. A penny apiece,
## carried in the bag, eaten when a long walk has run the energy down and the
## café is four hundred metres away — which is the whole reason it exists.
const CHOCOLATE := &"chocolate"

## In the order they are shown: cheapest first, dearest last. A child works
## down the shelf until the prices stop being numbers they have, and that only
## reads as a ladder if the ladder is in order. A check keeps this list sorted,
## because the obvious way to add something is to put it at the end.
const ALL: Array[StringName] = [
	CHOCOLATE, BOTTLE, AXE, SHEARS, LANTERN, WHISTLE, SADDLE, BICYCLE, QUAD, MOTORCYCLE,
]

## What is used up rather than owned. The wallet refuses to sell a thing twice,
## which is right for an axe and nonsense for a bar of chocolate.
const CONSUMABLE := {CHOCOLATE: true}

static func is_consumable(item: StringName) -> bool:
	return CONSUMABLE.has(item)

## What the shop buys, and for how much.
##
## The first thing this shop has ever bought rather than sold. A fleece grows
## back, so a flock is an income rather than a windfall — which is the point of
## the shears and the reason the sheep are worth walking out to.
const BUYS := {ItemKinds.WOOL: 2}

## How much wool one shear gives. One fleece, at two coins: see the economy
## notes at the top of this file.
const WOOL_PER_SHEEP := 1

static func pays_for(item: StringName) -> int:
	return int(BUYS.get(item, 0))

## How much of a child's energy a bar puts back. Less than a meal at the café,
## which costs three times as much and sits you down for it.
const CHOCOLATE_RESTORE := 0.22

## Shop prices, in the order they are shown. Twelve, twenty-four, twenty-eight,
## thirty-four were arrived at by tuning one price at a time against the animal
## that pays for it, and they read as noise. These are the numbers a child sees
## on a shelf in a real shop — nines all the way up — which makes the ladder
## legible at a glance and the top of it plainly a long way off.
const INFO := {
	CHOCOLATE: {"price": 1, "colour": Color(0.36, 0.22, 0.14)},
	BOTTLE: {"price": 19, "colour": Color(0.44, 0.72, 0.86)},
	AXE: {"price": 29, "colour": Color(0.70, 0.55, 0.35)},
	SHEARS: {"price": 39, "colour": Color(0.78, 0.80, 0.84)},
	LANTERN: {"price": 49, "colour": Color(0.96, 0.82, 0.42)},
	WHISTLE: {"price": 59, "colour": Color(0.80, 0.80, 0.84)},
	SADDLE: {"price": 79, "colour": Color(0.52, 0.32, 0.18)},
	BICYCLE: {"price": 99, "colour": Color(0.86, 0.42, 0.36)},
	QUAD: {"price": 199, "colour": Color(0.52, 0.33, 0.74)},
	# Three bicycles. It is the last thing anybody buys here, and it should
	# feel like the end of a long summer rather than the obvious next purchase.
	MOTORCYCLE: {"price": 299, "colour": Color(0.16, 0.20, 0.30)},
}

static func price(item: StringName) -> int:
	return INFO[item]["price"]

## How many of a thing a child may have at once.
##
## Buying a second one is allowed — things are objects here, and one left at
## the far side of the valley is no help at the counter — but not without end.
## Three of anything is a spare and a spare for the spare; two motorcycles and
## one quad, because those are the ones a child would otherwise simply buy
## again rather than walk back for.
const LIMIT := {MOTORCYCLE: 2, QUAD: 1}
const DEFAULT_LIMIT := 3

static func limit(item: StringName) -> int:
	return int(LIMIT.get(item, DEFAULT_LIMIT))

## What the shop gives for a thing brought back: half what it charged, rounded
## to the nearest coin.
##
## Half rather than all, because a shop that buys back at cost is a cupboard
## and there is no cost to a mistake; half rather than a tenth, because a child
## who saved ninety-nine coins for a bicycle and finds they wanted the quad
## should not be punished for changing their mind.
static func sells_back(item: StringName) -> int:
	return int(round(float(price(item)) * 0.5))

static func colour(item: StringName) -> Color:
	return INFO[item]["colour"]

static func label(item: StringName) -> String:
	return Text.of("shop_" + String(item))

## What the thing is for, in one line. Not on the shelf — the shelf is pictures
## and prices, because a shop of words excludes the child most likely to be
## saving up — but shown when a child taps a picture to ask about it.
static func description(item: StringName) -> String:
	return Text.of("shop_%s_what" % String(item))
