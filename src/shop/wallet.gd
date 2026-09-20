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
	return owned.has(item)

## Buy something. Returns false without spending anything if it is unaffordable
## or already owned, so a purchase can never half-succeed.
func buy(item: StringName, price: int) -> bool:
	if has(item) or not can_afford(price):
		return false
	coins -= price
	owned[item] = true
	changed.emit(coins)
	bought.emit(item)
	return true

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
	return {"coins": coins, "owned": owned.keys(), "tickets": tickets}

func from_data(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	tickets = int(data.get("tickets", 0))
	owned.clear()
	for item in data.get("owned", []):
		owned[StringName(item)] = true
	changed.emit(coins)
