class_name ShopStock
extends RefCounted

## What the shop sells.
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

const ALL: Array[StringName] = [
	CHOCOLATE, BOTTLE, AXE, SHEARS, SADDLE, LANTERN, BICYCLE, WHISTLE, MOTORCYCLE,
]

## What is used up rather than owned. The wallet refuses to sell a thing twice,
## which is right for an axe and nonsense for a bar of chocolate.
const CONSUMABLE := {CHOCOLATE: true}

static func is_consumable(item: StringName) -> bool:
	return CONSUMABLE.has(item)

## How much of a child's energy a bar puts back. Less than a meal at the café,
## which costs three times as much and sits you down for it.
const CHOCOLATE_RESTORE := 0.22

const INFO := {
	BOTTLE: {"price": 12, "colour": Color(0.44, 0.72, 0.86)},
	AXE: {"price": 20, "colour": Color(0.70, 0.55, 0.35)},
	LANTERN: {"price": 28, "colour": Color(0.96, 0.82, 0.42)},
	WHISTLE: {"price": 34, "colour": Color(0.80, 0.80, 0.84)},
	BICYCLE: {"price": 60, "colour": Color(0.86, 0.42, 0.36)},
	CHOCOLATE: {"price": 1, "colour": Color(0.36, 0.22, 0.14)},
	SHEARS: {"price": 24, "colour": Color(0.78, 0.80, 0.84)},
	SADDLE: {"price": 44, "colour": Color(0.52, 0.32, 0.18)},
	MOTORCYCLE: {"price": 140, "colour": Color(0.16, 0.20, 0.30)},
}

static func price(item: StringName) -> int:
	return INFO[item]["price"]

static func colour(item: StringName) -> Color:
	return INFO[item]["colour"]

static func label(item: StringName) -> String:
	return Text.of("shop_" + String(item))

static func description(item: StringName) -> String:
	return Text.of("shop_%s_what" % String(item))
