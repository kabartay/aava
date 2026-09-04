class_name Wiring
extends RefCounted

## How the interface, the build mode and the game are connected.
##
## This exists because the screenshot tool builds the same game the player does,
## and the first time it did so by hand it wired one signal fewer — so build
## mode never activated and the screenshot showed a game that was not the game.
## Two places connecting the same objects will always drift. One will not.
##
## Handlers arrive as a dictionary rather than as seventeen positional
## arguments. Seventeen was the point at which adding a control meant counting
## commas at three call sites, and a missing handler failed as "expected at
## least 17, received 14" rather than as the name of the thing forgotten.

## Every handler the interface can call. A missing one is reported by name.
const HANDLERS := [
	&"place", &"kick_start", &"kick_release", &"jump", &"remove",
	&"language", &"reset", &"care", &"shop", &"buy", &"drink", &"whistle", &"chop", &"ride", &"shoot_start", &"shoot_release", &"visit", &"dam",
]

static func connect_hud(
	hud: Hud,
	build_mode: BuildMode,
	camera_rig: CameraRig,
	inventory: Inventory,
	field: HeightField,
	player: Node3D,
	structures: Structures,
	handlers: Dictionary
) -> void:
	for name in HANDLERS:
		if not handlers.has(name):
			push_error("Wiring: no handler for '%s' — that control will do nothing" % name)

	hud.camera_dragged.connect(camera_rig.orbit)
	hud.camera_zoomed.connect(camera_rig.zoom)
	hud.build_toggled.connect(build_mode.set_active)
	hud.build_selected.connect(build_mode.select)
	build_mode.preview_changed.connect(hud.set_build_state)

	hud.build_place.connect(handlers.get(&"place", Callable()))
	hud.build_remove.connect(handlers.get(&"remove", Callable()))
	hud.kick_started.connect(handlers.get(&"kick_start", Callable()))
	hud.kick_released.connect(handlers.get(&"kick_release", Callable()))
	hud.jump_pressed.connect(handlers.get(&"jump", Callable()))
	hud.language_chosen.connect(handlers.get(&"language", Callable()))
	hud.reset_requested.connect(handlers.get(&"reset", Callable()))
	hud.care_pressed.connect(handlers.get(&"care", Callable()))
	hud.shop_toggled.connect(handlers.get(&"shop", Callable()))
	hud.shop_buy.connect(handlers.get(&"buy", Callable()))
	hud.drink_pressed.connect(handlers.get(&"drink", Callable()))
	hud.whistle_pressed.connect(handlers.get(&"whistle", Callable()))
	hud.chop_pressed.connect(handlers.get(&"chop", Callable()))
	hud.ride_pressed.connect(handlers.get(&"ride", Callable()))
	hud.shoot_started.connect(handlers.get(&"shoot_start", Callable()))
	hud.shoot_released.connect(handlers.get(&"shoot_release", Callable()))
	hud.place_used.connect(handlers.get(&"visit", Callable()))
	hud.dam_stick.connect(handlers.get(&"dam", Callable()))

	# The map is attached here rather than by the caller, because the
	# screenshot tool built its own interface and silently had no map — exactly
	# the drift this function exists to stop.
	var minimap := Minimap.new(field)
	minimap.follow(player, camera_rig, structures)
	hud.attach_minimap(minimap)

	inventory.changed.connect(hud.set_item_count)
	# Seed the display with what is already carried, because a signal only fires
	# on a change and a restored save has already changed.
	for kind in ItemKinds.ALL:
		hud.set_item_count(kind, inventory.count(kind))
