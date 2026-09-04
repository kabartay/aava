class_name Wiring
extends RefCounted

## How the interface, the build mode and the inventory are connected.
##
## This exists because the screenshot tool builds the same game the player does,
## and the first time it did so by hand it wired one signal fewer — so build
## mode never activated, the ghost never appeared, and the screenshot quietly
## showed a game that was not the game. Two places connecting the same objects
## will always drift. One will not.

static func connect_hud(
	hud: Hud,
	build_mode: BuildMode,
	camera_rig: CameraRig,
	inventory: Inventory,
	on_place: Callable,
	on_kick_start: Callable,
	on_kick_release: Callable,
	on_jump: Callable,
	on_remove: Callable,
	on_language: Callable,
	on_reset: Callable,
	field: HeightField,
	player: Node3D,
	structures: Structures
) -> void:
	hud.camera_dragged.connect(camera_rig.orbit)
	hud.camera_zoomed.connect(camera_rig.zoom)
	hud.build_toggled.connect(build_mode.set_active)
	hud.build_selected.connect(build_mode.select)
	hud.build_place.connect(on_place)
	hud.kick_started.connect(on_kick_start)
	hud.kick_released.connect(on_kick_release)
	hud.jump_pressed.connect(on_jump)
	hud.build_remove.connect(on_remove)
	hud.language_chosen.connect(on_language)
	hud.reset_requested.connect(on_reset)
	build_mode.preview_changed.connect(hud.set_build_state)

	# The map is attached here rather than by the caller, because the screenshot
	# tool built its own interface and silently had no map — exactly the drift
	# this function exists to stop.
	var minimap := Minimap.new(field)
	minimap.follow(player, camera_rig, structures)
	hud.attach_minimap(minimap)

	inventory.changed.connect(hud.set_item_count)
	# Seed the display with what is already carried, because a signal only fires
	# on a change and a restored save has already changed.
	for kind in ItemKinds.ALL:
		hud.set_item_count(kind, inventory.count(kind))
