class_name Venues
extends RefCounted

## What a cafe or a shop a child built does for them, apart from the game
## around it: the rules, so they can be played through without one.
##
## Whether a building counts as a cafe or a shop is Structures' business; this
## is only what happens when a child uses one.

## What a child's own cafe asks for a whole meal, if they ask anything.
const MEAL_PRICE := 1

## What a meal at home gives back, as a share of a meal at the valley's cafe:
## all of it for a coin, half of it for nothing. The choice is a real one.
const FREE_SHARE := 0.5

## How long a child waits between two free meals, in seconds of play: a fifth
## of a day. Kind but bounded — a free half meal whenever it was wanted was an
## endless supply of energy, which left the valley's cafe, and the coins it
## asks, with nothing to be for. A coin buys a whole meal at any time.
const FREE_WAIT := 240.0

const ATE := &"ate"
const FULL := &"full"
const POOR := &"poor"
const WAIT := &"wait"

## How much of the wait for a free meal is left, for saving: the clock the
## game keeps starts again at every launch, so a time of day means nothing next
## time but a number of seconds still to wait means the same.
static func wait_left(free_after: float, now: float) -> float:
	return clampf(free_after - now, 0.0, FREE_WAIT)

## Sit down to a meal at a table of one's own. Returns ATE, FULL (the bar was
## already full, and nothing was charged), POOR (a coin was asked for and
## there was not one) or WAIT (a free meal was asked for before `free_ready`
## said there was one: the caller keeps the clock, and nothing is eaten).
##
## `dish` is what was chosen from the menu (see Dishes). Asking a coin, a dish
## costs a third of what the valley's café charges for it, rounded up — so the
## soup is the one coin it always was, and a whole cake is two — and gives all
## of what it gives there. For nothing it gives half, and never more than half
## of the soup: a free pizza every wait would make the choice no choice.
static func eat(
	vitals: Vitals, wallet: Wallet, paying: bool, free_ready := true, dish := Dishes.USUAL
) -> StringName:
	if vitals.energy >= Vitals.MAX_ENERGY - 0.01:
		return FULL
	if not paying and not free_ready:
		return WAIT
	if paying and not wallet.spend(price_of(dish)):
		return POOR
	vitals.energy = Dishes.energy_after(vitals.energy, dish, 1.0) if paying else minf(
		Dishes.energy_after(vitals.energy, dish, FREE_SHARE),
		Dishes.energy_after(vitals.energy, Dishes.USUAL, FREE_SHARE)
	)
	return ATE

## What a dish costs at a café of one's own, when a coin is asked.
static func price_of(dish: StringName) -> int:
	return maxi(1, ceili(float(Dishes.price(dish)) / 3.0))

## Sell what the shop buys, at the price the shop in the valley pays. Returns
## how many things went and what they earned.
static func sell(inventory: Inventory, wallet: Wallet) -> Vector2i:
	var sold := 0
	var earned := 0
	for item in ShopStock.BUYS:
		var carried := inventory.count(item)
		if carried <= 0 or not inventory.spend({item: carried}):
			continue
		sold += carried
		earned += carried * ShopStock.pays_for(item)
	if earned > 0:
		wallet.earn(earned)
	return Vector2i(sold, earned)
