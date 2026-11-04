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

## Where this list and the saves live. Always FOLDER in the game; a variable
## so that the checks can break a folder of their own without touching a real
## family's.
var folder := FOLDER

## A rename the phone was killed in the middle of: the child's old and new
## names, kept in the index until every save has moved (see rename_player).
var pending_rename := {}

func index_path() -> String:
	return folder + "/index.json"

## Load the index, or start a fresh one.
func load_index() -> void:
	players.clear()
	worlds.clear()
	maps = {HOME_MAP: HOME_SEED}
	current_player = ""
	current_world = ""
	pending_rename = {}

	# Read the way a save is: the index, else the copy kept beside it, with
	# anything unreadable set aside under a name of its own and never deleted.
	# This file is the list of who is who: lose it and every child's save is
	# still on the phone with nothing pointing at it, so when nothing at all
	# can be read the list is rebuilt from the saves themselves below.
	var data := SaveGame.read_versioned(index_path(), VERSION)
	# Whole, but from the copy beside it: the index itself is missing or was
	# set aside, so it is written again in its own place.
	var from_copy := not data.is_empty() and not FileAccess.file_exists(index_path())
	_fill_from(data)
	if reconcile(data.is_empty()) or from_copy:
		save_index()

func _fill_from(data: Dictionary) -> void:
	# Each container is checked for its type before it is walked: a hand-edited
	# index with "players" as a string, or a world that is a number, keeps what
	# is valid instead of erroring and losing the lot.
	var saved_players = data.get("players", [])
	if saved_players is Array:
		for name in saved_players:
			# One child once: "Amir" and "amir" are one file, so an index naming
			# both must not list two children who then write over each other.
			if name is String and is_valid_name(name) and player_named(name).is_empty():
				players.append(name)
	var saved_maps = data.get("maps", {})
	if saved_maps is Dictionary:
		for key in saved_maps:
			if (saved_maps[key] is float or saved_maps[key] is int) and _is_safe_id(String(key)):
				maps[String(key)] = int(saved_maps[key])

	var saved_worlds = data.get("worlds", {})
	if saved_worlds is Dictionary:
		for id in saved_worlds:
			if saved_worlds[id] is not Dictionary or not _is_safe_id(String(id)):
				continue
			var entry: Dictionary = saved_worlds[id]
			var map_name := String(entry.get("map", HOME_MAP))
			# A world whose map template is gone cannot be generated, so it is
			# dropped rather than loaded into a valley that does not exist.
			if not maps.has(map_name):
				continue
			var guests: Array[String] = []
			var saved_guests = entry.get("guests", [])
			if saved_guests is Array:
				for guest in saved_guests:
					# Once each, and never the owner: remove_player and
					# uninvite erase one entry, so a name listed twice stayed
					# invited after being taken away.
					if not guests.has(String(guest)) and String(guest) != String(entry.get("owner", "")):
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
	var pending = data.get("renaming", {})
	if pending is Dictionary and pending.get("from") is String and pending.get("to") is String:
		pending_rename = {"from": pending["from"], "to": pending["to"]}

## Written the way a save is — beside the file and renamed over it — because
## it was opened in place, which empties it before a byte of the new list goes
## in, and a phone that kills the game in that moment left an empty list of
## children with all of their saves still on the disk.
func save_index() -> bool:
	var data := {
		"players": players,
		"maps": maps,
		"worlds": worlds,
		"current_player": current_player,
		"current_world": current_world,
	}
	if not pending_rename.is_empty():
		data["renaming"] = pending_rename
	# SaveGame.write keeps the list it replaces as `.previous`, so a list
	# that comes back unreadable has the last whole one to go back to.
	return SaveGame.write(data, index_path(), VERSION)

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
		# Ё and ё sit outside the А–я block, so "Артём" and "Фёдор" were refused.
		var cyrillic := (code >= 0x0410 and code <= 0x044F) or code == 0x0401 or code == 0x0451
		# The accented letters French is written with (Zoé, Léa, Noël, Inès),
		# less the multiplication and division signs that sit among them. The
		# game is played in French, so its children's names must be allowed.
		var accented := code >= 0xC0 and code <= 0xFF and code != 0xD7 and code != 0xF7
		var digit := code >= 48 and code <= 57
		if not (latin or cyrillic or accented or digit or character == " " or character == "-"):
			return false
	# Not the one name whose file is already spoken for. A player's save is
	# "<name>--<valley>" and the valley's own is "world--<valley>", so a child
	# called World shared a file with the valley, and every save wrote the
	# child's bag over the houses and then the houses over the bag.
	if _slug(trimmed) == "world":
		return false
	return true

## The player already on this phone whose name is this one, as far as their
## file is concerned — "Amir" and "amir" are one file — or an empty string.
func player_named(name: String) -> String:
	var wanted := _key(name)
	for each in players:
		if _key(each) == wanted:
			return each
	return ""

## A name as it is stored: the ends trimmed and every run of spaces made one.
## "Amir  Ali" and "Amir Ali" read as the same name to a six-year-old and to
## a sibling, so they must not be two children. Only new names are tidied; a
## name already in the index keeps the spelling its files were made under.
static func tidy(name: String) -> String:
	var out := name.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out

func add_player(name: String) -> bool:
	var trimmed := tidy(name)
	if not is_valid_name(trimmed) or not player_named(trimmed).is_empty():
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
		# The copy kept beside it goes too, or a child of the same name made
		# later would be handed the removed one's valley back.
		for leftover: String in [path, path + ".previous", path + ".writing"]:
			if FileAccess.file_exists(leftover):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))
	for id in worlds:
		var guests: Array = worlds[id]["guests"]
		guests.erase(name)
	# The world remembered must still be one the child now playing may enter,
	# or the next start would be walking about in the removed child's valley.
	if not current_world_is_enterable():
		var theirs := worlds_for(current_player)
		current_world = theirs[0] if not theirs.is_empty() else ""
	save_index()
	return true

## Give a child a new name, and take everything that was theirs with them: their
## progress in every valley, the valleys they own and the ones they were
## invited to.
##
## A rename used to be a copy. The new name was added and this child's state
## written under it, and the old name's files stayed where they were — so a
## child who renamed and then wanted their old name back was told it was taken,
## by the copy of themselves they had left behind, for good.
##
## `old_name` may be empty: the child playing before anyone had chosen a name.
func rename_player(old_name: String, new_name: String) -> bool:
	var trimmed := tidy(new_name)
	if not is_valid_name(trimmed):
		return false
	# Taken by somebody else is a refusal; taken by this child themselves is a
	# change of capitals or spaces ("amir" to "Amir"), which was refused as
	# "already used" by the child's own old name.
	var existing := player_named(trimmed)
	if not existing.is_empty() and existing != old_name:
		return false
	var at := players.find(old_name)
	if at >= 0:
		players[at] = trimmed
	else:
		players.append(trimmed)
	for id in worlds:
		var world: Dictionary = worlds[id]
		if String(world["owner"]) == old_name:
			world["owner"] = trimmed
		var guests: Array = world["guests"]
		var guest_at := guests.find(old_name)
		if guest_at >= 0:
			guests[guest_at] = trimmed
	if current_player == old_name:
		current_player = trimmed
	# The index goes first, saying a rename is under way, and the files move
	# after it. Written last it left a kill between the two with an index
	# still on the old name and saves under the new one, which nothing could
	# put right. Now the next start finishes the move (see reconcile).
	if not old_name.is_empty():
		pending_rename = {"from": old_name, "to": trimmed}
		save_index()
	_move_saves(old_name, trimmed)
	pending_rename = {}
	save_index()
	return true

## Move every save of one child, and the copy beside it, from one name to
## another. Safe to run twice: it only moves what is still where it was.
func _move_saves(old_name: String, new_name: String) -> void:
	for id in worlds:
		var from := ProjectSettings.globalize_path(save_path_for(old_name, String(id)))
		var to := ProjectSettings.globalize_path(save_path_for(new_name, String(id)))
		if from == to:
			continue
		# The save and the copy beside it move on their own: a phone killed
		# between the two renames inside SaveGame.write leaves only the copy,
		# and that was left behind under the old name.
		for suffix: String in ["", ".previous"]:
			if not FileAccess.file_exists(from + suffix):
				continue
			# Anything already at the new name (a leftover from a crash) is
			# kept aside, never written over and never the reason this child's
			# own save stays behind under a name nobody plays as.
			if FileAccess.file_exists(to + suffix):
				SaveGame.set_aside(to + suffix)
			DirAccess.rename_absolute(from + suffix, to + suffix)

## Make the index and the folder agree after a start that may follow a crash.
## Returns true if the index was changed and should be written.
##
## Three things, in this order. A rename that was interrupted is finished.
## Then every save file in the folder is looked at, and one whose child or
## valley the index does not know is attached to a profile named by its file
## name, never ignored: a parent who opens the folder sees whose afternoon is
## in which file, and the game must see the same. Lastly, when no index could
## be read at all (`rebuild`), the child who played most recently is the one
## chosen, judged by which save was written last.
##
## Only the saves are read from names: `<name>--<valley>.json`, or the same
## with `.previous` for one whose second rename never happened. Files kept
## aside (`.unreadable`) and half-written ones (`.writing`) are not saves, so
## they can neither be mistaken for one nor hide one, and nothing is deleted.
func reconcile(rebuild := false) -> bool:
	var changed := false
	if not pending_rename.is_empty():
		var from := String(pending_rename["from"])
		var to := String(pending_rename["to"])
		if players.has(to):
			_move_saves(from, to)
		pending_rename = {}
		changed = true
	var newest := -1
	var newest_player := ""
	var newest_world := ""
	var names := DirAccess.get_files_at(folder)
	names.sort()
	for file_name in names:
		var stem := ""
		if file_name.ends_with(".json"):
			stem = file_name.trim_suffix(".json")
		elif file_name.ends_with(".json.previous"):
			stem = file_name.trim_suffix(".json.previous")
		else:
			continue
		var found := _split_save_name(stem)
		if found.is_empty():
			continue
		var slug: String = found[0]
		var world_id: String = found[1]
		if slug == "world":
			continue
		var owner := ""
		for each in players:
			if _slug(each) == slug:
				owner = each
		if owner.is_empty():
			# Capitals are lost in a file name; the first letter is put back
			# so a parent sees "Amir" and not "amir".
			var guess := slug.substr(0, 1).to_upper() + slug.substr(1)
			if not is_valid_name(guess) or not player_named(guess).is_empty():
				continue
			owner = guess
			players.append(owner)
			changed = true
			push_warning("save %s had no profile; added %s" % [file_name, owner])
		if not worlds.has(world_id):
			var map_name := _map_of_slug(world_id)
			if map_name.is_empty():
				push_warning("save %s is in a valley the index does not know and no map to make it from" % file_name)
				continue
			worlds[world_id] = {"map": map_name, "owner": owner, "guests": []}
			changed = true
		elif not may_enter(world_id, owner):
			(worlds[world_id]["guests"] as Array).append(owner)
			changed = true
		var stamp := FileAccess.get_modified_time(folder + "/" + file_name)
		if stamp > newest:
			newest = stamp
			newest_player = owner
			newest_world = world_id
	if rebuild and not newest_player.is_empty():
		current_player = newest_player
		current_world = newest_world
		changed = true
	return changed

## A save's file name, without its ending, as [name slug, valley id]. The
## split is at the "--" that leaves a valley the index knows; failing that,
## at the last one.
func _split_save_name(stem: String) -> Array:
	var cuts: Array[int] = []
	var from := 0
	while true:
		var at := stem.find("--", from)
		if at < 0:
			break
		cuts.append(at)
		from = at + 1
	if cuts.is_empty():
		return []
	for cut in cuts:
		if worlds.has(stem.substr(cut + 2)) and cut > 0:
			return [stem.substr(0, cut), stem.substr(cut + 2)]
	var last: int = cuts[cuts.size() - 1]
	if last == 0 or last + 2 >= stem.length():
		return []
	return [stem.substr(0, last), stem.substr(last + 2)]

## The map a valley id was made from ("home-2" is a copy of "home"), or an
## empty string. A valley whose map is not known is left alone rather than
## given the wrong ground.
func _map_of_slug(world_id: String) -> String:
	var dash := world_id.rfind("-")
	if dash <= 0 or not world_id.substr(dash + 1).is_valid_int():
		return ""
	var prefix := world_id.substr(0, dash)
	for map_name in maps:
		if _slug(String(map_name)) == prefix:
			return String(map_name)
	return ""

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
		return "%s/%s.json" % [folder, _slug(world_id)]
	return "%s/%s--%s.json" % [folder, _slug(player), _slug(world_id)]

## Is the world the game is pointing at one the current player may be in? The
## index remembers the world last played, and a different child chosen since —
## on the command line, or by hand — has no right to it: they would be walking
## about in somebody else's valley, saving their bag into its files.
func current_world_is_enterable() -> bool:
	return may_enter(current_world, current_player)

func current_save_path() -> String:
	return save_path_for(current_player, current_world)

## What the world itself holds, as opposed to what one player carries: the
## structures, the felled trees, the dams. Shared by everyone in this copy,
## which is what makes an invitation mean something.
func world_path_for(world_id: String) -> String:
	return "%s/world--%s.json" % [folder, _slug(world_id)]

func current_world_path() -> String:
	return world_path_for(current_world)

## Lower case, spaces to hyphens. Names are already restricted to characters
## that need no escaping, so this only has to be tidy.
static func _slug(name: String) -> String:
	return name.strip_edges().to_lower().replace(" ", "-")


## The identity of a name for "is this child already here": the slug with runs
## of spaces made one, so "Amir  Ali", "amir ali" and "Amir-Ali" are one child.
static func _key(name: String) -> String:
	return _slug(tidy(name))

## Map names and world ids come out of the index file, which a parent may edit
## by hand, and are used to build paths. Anything that could leave the folder
## is dropped rather than followed.
static func _is_safe_id(id: String) -> bool:
	if id.is_empty():
		return false
	for bad: String in ["/", "\\", ":", "."]:
		if id.contains(bad):
			return false
	return true
