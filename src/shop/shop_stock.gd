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

const ALL: Array[StringName] = [BOTTLE, AXE, LANTERN, BICYCLE, WHISTLE]

const INFO := {
	BOTTLE: {"price": 12, "colour": Color(0.44, 0.72, 0.86)},
	AXE: {"price": 20, "colour": Color(0.70, 0.55, 0.35)},
	LANTERN: {"price": 28, "colour": Color(0.96, 0.82, 0.42)},
	WHISTLE: {"price": 34, "colour": Color(0.80, 0.80, 0.84)},
	BICYCLE: {"price": 60, "colour": Color(0.86, 0.42, 0.36)},
}

static func price(item: StringName) -> int:
	return INFO[item]["price"]

static func colour(item: StringName) -> Color:
	return INFO[item]["colour"]

static func label(item: StringName) -> String:
	return Text.of("shop_" + String(item))

static func description(item: StringName) -> String:
	return Text.of("shop_%s_what" % String(item))
