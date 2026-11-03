class_name Dishes
extends RefCounted

## What the café serves: six dishes, each with its own price and its own worth
## in energy, so that choosing one is a real choice and not a button.
##
## This is the menu and nothing else — the picture on the wall, the tiles on
## the screen, the plate on the table and the coins that change hands all read
## it, and the checks hold each of them to it. A price written in the HUD and a
## different one charged in main.gd is a child robbed with a smile.
##
## `restore` is a share of a full bar, as Places.MEAL_RESTORE always was; the
## soup is that meal, unchanged, so a child who simply holds the eat button
## still gets what they always did.

const JUICE := &"juice"
const PANCAKE := &"pancake"
const SOUP := &"soup"
const PIZZA := &"pizza"
const ICE_CREAM := &"icecream"
const CAKE := &"cake"

## In the order they are drawn, cheapest first, on the wall and on the screen.
const ALL: Array[StringName] = [JUICE, ICE_CREAM, PANCAKE, SOUP, PIZZA, CAKE]

## What the child has chosen when nothing has been chosen yet.
const USUAL := SOUP

## `name` is the key of its word in Text, written out in full so that a line
## nobody asks for can be found by searching for it.
const MENU := {
	JUICE: {"price": 1, "restore": 0.15, "name": "dish_juice"},
	ICE_CREAM: {"price": 2, "restore": 0.20, "name": "dish_icecream"},
	PANCAKE: {"price": 2, "restore": 0.30, "name": "dish_pancake"},
	SOUP: {"price": 3, "restore": 0.55, "name": "dish_soup"},
	PIZZA: {"price": 4, "restore": 0.75, "name": "dish_pizza"},
	CAKE: {"price": 6, "restore": 0.90, "name": "dish_cake"},
}

static func name_key(dish: StringName) -> String:
	return String((MENU[dish] as Dictionary)["name"])

## Ice cream cools a child down after running: for this many seconds of play
## the energy comes back this many times as fast, as it does beside a fire.
const COOL_SECONDS := 30.0
const COOL_BOOST := 2.0

## How many bites a plate is eaten in, which is how many steps it empties by.
const BITES := 4

static func is_dish(dish: StringName) -> bool:
	return MENU.has(dish)

static func price(dish: StringName) -> int:
	return int((MENU[dish] as Dictionary)["price"])

static func restore(dish: StringName) -> float:
	return float((MENU[dish] as Dictionary)["restore"])

## Whether the dish leaves a child cooled down.
static func cools(dish: StringName) -> bool:
	return dish == ICE_CREAM

## What the dish gives, as a whole number of percent of a full bar, for
## the line under the tiles.
static func percent(dish: StringName) -> int:
	return roundi(restore(dish) * 100.0)

## A dish as a number, for sending to the other child: its place on the menu.
static func index_of(dish: StringName) -> int:
	return ALL.find(dish)

## And back again. Anything that is not on the menu — a number from a phone
## that is not to be trusted — is no dish at all.
static func from_index(index: int) -> StringName:
	return ALL[index] if index >= 0 and index < ALL.size() else &""

## What a child's bar becomes after eating `dish`, `share` of its worth.
static func energy_after(energy: float, dish: StringName, share := 1.0) -> float:
	return minf(Vitals.MAX_ENERGY, energy + Vitals.MAX_ENERGY * restore(dish) * share)
