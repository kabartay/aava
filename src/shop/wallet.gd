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

func to_data() -> Dictionary:
	return {"coins": coins, "owned": owned.keys()}

func from_data(data: Dictionary) -> void:
	coins = int(data.get("coins", 0))
	owned.clear()
	for item in data.get("owned", []):
		owned[StringName(item)] = true
	changed.emit(coins)
