class_name Profiles
extends RefCounted

## Who is playing, and which valley they are in.
##
## Until now there was one save file, which meant three children shared one
## world whether they wanted to or not — the eldest's house and the six-year-
## old's animals in the same valley, and a reset by either wiping both. That is
## sometimes exactly right and sometimes a quarrel.
##
## Three things, not two, and the distinction matters:
##
## A **map** is a template — a name and a seed. "The valley" is one map, the way
## a Call of Duty map is one map: everybody recognises it, and it is the same
## every time.
##
## A **world** is one copy of a map that is actually being played in. Two
## children can each have their own copy of the same valley: same river, same
## hills, same football pitch, but the house one of them built is not in the
## other's. This is the piece that was missing — without it, "share a map" and
## "play alone" could not both be true of the same valley.
##
## A **player** is a child. A player owns worlds and can be invited into someone
## else's; being invited puts them in *that* copy, not in a copy of their own.
##
## Doing the split now, while it is all files on one machine, means the
## networked version has somewhere to attach: joining over a network is opening
## someone else's world instead of your own.
##
## The file layout is deliberately flat and readable, for the same reason the
## save itself is JSON: when something goes wrong a parent should be able to
## open the folder and see whose afternoon is in which file.

const FOLDER := "user://players"
const INDEX := "user://players/index.json"

const VERSION := 1

## The default map every new player starts on, so that brothers who each make a
## profile still end up in the same valley unless they ask not to.
const HOME_MAP := "home"
const HOME_SEED := 20260903

## Names are used to build file paths, so they are restricted rather than
## sanitised — a child typing an emoji should be told no, not have it silently
## turned into something else.
const MAX_NAME := 16

var players: Array[String] = []

## Map templates: name to seed. Small and fixed — these are the places the game
## offers, not the copies of them.
var maps: Dictionary = {}

## Every world that exists, keyed by its id. Each holds which map it is a copy
## of, who made it, and who has been invited.
var worlds: Dictionary = {}

var current_player := ""
var current_world := ""

## Load the index, or start a fresh one.
func load_index() -> void:
	players.clear()
	worlds.clear()
	maps = {HOME_MAP: HOME_SEED}
	current_player = ""
	current_world = ""

	if not FileAccess.file_exists(INDEX):
		return
	var file := FileAccess.open(INDEX, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("player index is not valid JSON; starting fresh")
		return

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		push_warning("player index is version %s, expected %d" % [data.get("version"), VERSION])
		return

	for name in data.get("players", []):
		if is_valid_name(String(name)):
			players.append(String(name))
	var saved_maps: Dictionary = data.get("maps", {})
	for key in saved_maps:
		maps[String(key)] = int(saved_maps[key])

	var saved_worlds: Dictionary = data.get("worlds", {})
	for id in saved_worlds:
		var entry: Dictionary = saved_worlds[id]
		var map_name := String(entry.get("map", HOME_MAP))
		# A world whose map template is gone cannot be generated, so it is
		# dropped rather than loaded into a valley that does not exist.
		if not maps.has(map_name):
			continue
		var guests: Array[String] = []
		for guest in entry.get("guests", []):
			guests.append(String(guest))
		worlds[String(id)] = {
			"map": map_name,
			"owner": String(entry.get("owner", "")),
			"guests": guests,
		}

	# Restored only if it still exists: a profile deleted on another device, or
	# by hand, must not leave the game pointing at nothing.
	var last := String(data.get("current_player", ""))
	if players.has(last):
		current_player = last
	var last_world := String(data.get("current_world", ""))
	if worlds.has(last_world):
		current_world = last_world

func save_index() -> bool:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(FOLDER)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var file := FileAccess.open(INDEX, FileAccess.WRITE)
	if file == null:
		push_warning("could not write the player index")
		return false
	file.store_string(JSON.stringify({
		"version": VERSION,
		"players": players,
		"maps": maps,
		"worlds": worlds,
		"current_player": current_player,
		"current_world": current_world,
	}, "\t"))
	return true

## A name has to be usable as a filename and readable by a six-year-old. Latin
## letters, Cyrillic, digits, spaces and hyphens — enough for the three names
## this was written for, and nothing that needs escaping.
static func is_valid_name(name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed.is_empty() or trimmed.length() > MAX_NAME:
		return false
	for character in trimmed:
		var code := character.unicode_at(0)
		var latin := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var cyrillic := code >= 0x0410 and code <= 0x044F
		var digit := code >= 48 and code <= 57
		if not (latin or cyrillic or digit or character == " " or character == "-"):
			return false
	return true

func add_player(name: String) -> bool:
	var trimmed := name.strip_edges()
	if not is_valid_name(trimmed) or players.has(trimmed):
		return false
	players.append(trimmed)
	save_index()
	return true

## Deleting a player leaves worlds alone. A valley two children built together
## should not vanish because one of them was removed, and the guest list is what
## makes it theirs jointly.
func remove_player(name: String) -> bool:
	if not players.has(name):
		return false
	players.erase(name)
	if current_player == name:
		current_player = players[0] if not players.is_empty() else ""
	# Only their own progress files go, since nothing else can read them.
	for id in worlds:
		var path := save_path_for(name, String(id))
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for id in worlds:
		var guests: Array = worlds[id]["guests"]
		guests.erase(name)
	save_index()
	return true

func choose_player(name: String) -> bool:
	if not players.has(name):
		return false
	current_player = name
	save_index()
	return true

## Add a map template — a new kind of valley the game can make copies of.
func add_map(name: String, seed_value: int) -> bool:
	var trimmed := name.strip_edges()
	if not is_valid_name(trimmed) or maps.has(trimmed):
		return false
	maps[trimmed] = seed_value
	save_index()
	return true

func seed_of(map: String) -> int:
	return int(maps.get(map, HOME_SEED))

## Start a fresh copy of a map. This is what "each new world starts from
## default" means: the ground comes from the map's seed, and nothing has been
## built, felled or dammed in it yet.
##
## Returns the new world's id, or an empty string.
func create_world(map: String, owner: String) -> String:
	if not maps.has(map):
		return ""
	# Numbered per map, so an id reads as what it is: "home-2" is the second
	# copy of the valley. Sequential rather than random because a parent looking
	# in the folder should be able to tell which file is which.
	var index := 1
	while worlds.has("%s-%d" % [_slug(map), index]):
		index += 1
	var id := "%s-%d" % [_slug(map), index]
	worlds[id] = {"map": map, "owner": owner, "guests": []}
	save_index()
	return id

func choose_world(id: String) -> bool:
	if not worlds.has(id):
		return false
	current_world = id
	save_index()
	return true

func map_of(world_id: String) -> String:
	if not worlds.has(world_id):
		return HOME_MAP
	return String(worlds[world_id]["map"])

func seed_of_world(world_id: String) -> int:
	return seed_of(map_of(world_id))

func owner_of(world_id: String) -> String:
	if not worlds.has(world_id):
		return ""
	return String(worlds[world_id]["owner"])

## Invite a player into a world. This is the whole point of the split: being
## invited puts a child in *this* copy of the valley — the one with your house
## in it — rather than in a copy of their own.
func invite(world_id: String, player: String) -> bool:
	if not worlds.has(world_id) or not players.has(player):
		return false
	if owner_of(world_id) == player:
		return false
	var guests: Array = worlds[world_id]["guests"]
	if guests.has(player):
		return false
	guests.append(player)
	save_index()
	return true

func uninvite(world_id: String, player: String) -> bool:
	if not worlds.has(world_id):
		return false
	var guests: Array = worlds[world_id]["guests"]
	if not guests.has(player):
		return false
	guests.erase(player)
	save_index()
	return true

func may_enter(world_id: String, player: String) -> bool:
	if not worlds.has(world_id):
		return false
	if owner_of(world_id) == player:
		return true
	return (worlds[world_id]["guests"] as Array).has(player)

## Every world a player can walk into: the ones they made, and the ones they
## have been invited to.
func worlds_for(player: String) -> Array[String]:
	var out: Array[String] = []
	for id in worlds:
		if may_enter(String(id), player):
			out.append(String(id))
	return out

## Where one player's own progress in one world lives — their bag, their coins,
## their journal. Separate per player, because two children in one valley each
## have their own afternoon even while sharing the ground.
func save_path_for(player: String, world_id: String) -> String:
	if player.is_empty():
		return "%s/%s.json" % [FOLDER, _slug(world_id)]
	return "%s/%s--%s.json" % [FOLDER, _slug(player), _slug(world_id)]

func current_save_path() -> String:
	return save_path_for(current_player, current_world)

## What the world itself holds, as opposed to what one player carries: the
## structures, the felled trees, the dams. Shared by everyone in this copy,
## which is what makes an invitation mean something.
func world_path_for(world_id: String) -> String:
	return "%s/world--%s.json" % [FOLDER, _slug(world_id)]

func current_world_path() -> String:
	return world_path_for(current_world)

## Lower case, spaces to hyphens. Names are already restricted to characters
## that need no escaping, so this only has to be tidy.
static func _slug(name: String) -> String:
	return name.strip_edges().to_lower().replace(" ", "-")
