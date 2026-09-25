class_name Wallet
extends RefCounted

## Coins, and the things a child has already bought.
##
## Separate from the inventory because coins are not carried and cannot be
## dropped: they are a record of what has been done, and the shop is what turns
## that record back into something to do. Without the shop, feeding a squirrel
## is a number going up; with it, four cones is a bicycle.

signal changed(total: int)
signal bought(item: StringName)

var coins := 0

## What the child has, and how many of each.
##
## It used to be a set of flags: you owned a bicycle or you did not. That is a
## licence rather than a possession, and it broke the moment a thing could be
## left somewhere — a bicycle abandoned at the far side of the valley still
## counted as owned, so the shop refused to sell another and a child standing
## at the counter could not ride home. Things in this valley are objects: you
## can have two bicycles, and the price is what stops you.
var owned: Dictionary = {}

## Rides bought at the fairground's kiosk and not yet used. Kept as a count
## rather than as a thing owned: a ticket is spent the moment a ride starts,
## which is what makes buying five of them mean anything.
var tickets := 0

func earn(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	changed.emit(coins)

func can_afford(price: int) -> bool:
	return coins >= price

func has(item: StringName) -> bool:
	return count_of(item) > 0

## How many of a thing the child has.
func count_of(item: StringName) -> int:
	return int(owned.get(item, 0))

## Buy something. Returns false without spending anything if it is unaffordable
## or already owned, so a purchase can never half-succeed.
## Buy something. Returns false without spending anything if it is
## unaffordable, so a purchase can never half-succeed.
##
## Buying a second one is allowed. What a child pays for is the thing, not the
## right to have one: if the first bicycle is at the lake and they are at the
## counter, another ninety-nine coins buys another bicycle, and the valley then
## has two bicycles in it, which is exactly what happened.
func buy(item: StringName, price: int) -> bool:
	if not can_afford(price):
		return false
	coins -= price
	owned[item] = count_of(item) + 1
	changed.emit(coins)
	bought.emit(item)
	return true

## Put one down, or lose it. False if there was none to put down.
func give_up(item: StringName) -> bool:
	if not has(item):
		return false
	var left := count_of(item) - 1
	if left <= 0:
		owned.erase(item)
	else:
		owned[item] = left
	changed.emit(coins)
	return true

## Sell one back to the shop. Returns what was paid for it, or nothing if
## there was none to sell.
func sell_back(item: StringName, price: int) -> int:
	if not give_up(item):
		return 0
	earn(price)
	return price

## Take one in, without paying: picked up off the ground, or handed over.
func take(item: StringName) -> void:
	owned[item] = count_of(item) + 1
	changed.emit(coins)

## Pay for something that is not kept — a meal, a ride. `buy` records what was
## bought and refuses to charge twice for it, which is right for a bicycle and
## wrong for lunch.
func spend(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	changed.emit(coins)
	return true

## Buy one ride at the fairground. Returns false and spends nothing if there
## are not the coins for it.
func buy_ticket(price: int) -> bool:
	if not spend(price):
		return false
	tickets += 1
	changed.emit(coins)
	return true

## Hand one over at the gate of a ride. False if there is none to hand over.
func use_ticket() -> bool:
	if tickets <= 0:
		return false
	tickets -= 1
	changed.emit(coins)
	return true

func to_data() -> Dictionary:
	return {"coins": coins, "owned": owned.duplicate(), "tickets": tickets}

func from_data(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	tickets = int(data.get("tickets", 0))
	owned.clear()
	# Two shapes. A dictionary of counts is what is written now; a bare list of
	# names is every world saved before a child could have two of anything, and
	# those load as one each.
	var kept = data.get("owned", {})
	if kept is Dictionary:
		for item in kept:
			owned[StringName(item)] = maxi(1, int(kept[item]))
	else:
		for item in kept:
			owned[StringName(item)] = 1
	changed.emit(coins)
