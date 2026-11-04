class_name SaveGame
extends RefCounted

## Reading and writing the one save file.
##
## Plain JSON rather than a Godot resource, for a reason that matters in a
## family project: when something goes wrong, a parent can open the file, read
## it, and see that his child's afternoon of building is still in there. A
## binary resource offers no such reassurance, and loading one runs whatever
## script it names.

## Where the single-profile game used to save. Kept so that a valley built
## before profiles existed is not silently abandoned — see `migrate_legacy`.
const PATH := "user://aava-save.json"

## Bumped whenever the shape of the file changes. Old saves are then migrated or
## refused explicitly, rather than crashing on a missing key.
const VERSION := 1

## `version` is stamped into the file: this file's own by default, or the
## caller's for a file with a shape of its own, like the player index.
static func write(data: Dictionary, path := PATH, version := VERSION) -> bool:
	data["version"] = version
	# The folder may not exist yet on a first run with profiles.
	var folder := path.get_base_dir()
	if not folder.is_empty() and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	# Written beside the real file and renamed over it, never into it.
	#
	# Opening the save itself for writing truncates it to nothing before a byte
	# of the new content is stored, and this is a phone game: Android kills a
	# backgrounded app whenever it wants the memory, and a battery goes flat
	# mid-afternoon. Land in that window and the file left behind is half a
	# JSON document, which `read()` cannot parse, so the game starts a brand
	# new valley — and the autosave twenty seconds later writes that empty
	# valley over the wreckage. A child's house is then gone past recovering,
	# which is precisely what the readable-JSON promise above was for.
	#
	# A rename within one directory is atomic: the save is either entirely the
	# old afternoon or entirely the new one, and never half of each.
	var scratch := path + ".writing"
	var file := FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		push_warning("could not write %s: %s" % [scratch, error_string(FileAccess.get_open_error())])
		return false
	var stored := file.store_string(JSON.stringify(_finite(data), "\t"))
	var trouble := file.get_error()
	# Closed explicitly rather than when the handle happens to fall out of
	# scope, because the rename below must not overtake the last of the bytes.
	file.close()
	# And only renamed over the real save if every byte went in. A phone with
	# its storage full writes part of a file and says so here; the rename
	# below then put that part over a whole afternoon, which is the exact loss
	# writing beside the file was meant to prevent.
	if not stored or trouble != OK:
		push_warning("could not finish writing %s: %s" % [scratch, error_string(trouble)])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false

	var folder_access := DirAccess.open(path.get_base_dir())
	if folder_access == null:
		push_warning("could not reach %s to save into" % path.get_base_dir())
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false
	# The save being replaced is kept for one more round as `.previous`. The
	# rename above makes a half-written save unlikely, not impossible: a flash
	# chip can still hand back a file that parses as nothing, and without a
	# second copy the game then starts a new valley beside the unreadable one.
	# With it, `read()` has the last whole afternoon to go back to.
	var previous := path + ".previous"
	var kept_previous := false
	if FileAccess.file_exists(path):
		kept_previous = folder_access.rename(path.get_file(), previous.get_file()) == OK
	var renamed := folder_access.rename(scratch.get_file(), path.get_file())
	if renamed != OK:
		push_warning("could not put %s in place: %s" % [path, error_string(renamed)])
		# The save that was moved aside goes back where it was.
		if kept_previous:
			folder_access.rename(previous.get_file(), path.get_file())
		# The scratch file is a whole copy of the save; left behind it is
		# clutter, so it goes.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false
	return true

## The same data with every number that is not a number put to nought.
##
## JSON has no way to say NaN or infinity, and the stringifier writes them as
## the bare words `nan` and `inf`, which `read()` then cannot parse: one bad
## float anywhere — a camera angle, a position after a divide by nothing — made
## the whole file unreadable, so the next start set the child's valley aside
## and began a new one. The write was whole and the rename atomic and it still
## lost the afternoon. Nought is a wrong value for one field; an unreadable
## file is a wrong value for all of them.
static func _finite(value: Variant) -> Variant:
	if value is float:
		return value if is_finite(value) else 0.0
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _finite(value[key])
		return out
	if value is Array:
		var out := []
		for item in value:
			out.append(_finite(item))
		return out
	return value

static func read(path := PATH) -> Dictionary:
	return read_versioned(path, VERSION)

## `read()` for a file with a version of its own, like the player index: the
## same fallback to `.previous` and the same setting aside, so the list of
## children is as hard to lose as a child's valley.
static func read_versioned(path: String, version: int) -> Dictionary:
	var previous := path + ".previous"
	if not FileAccess.file_exists(path):
		# Killed between the two renames in `write()`: the save is only
		# missing its name, and the last whole copy is sitting beside it.
		return _read_whole(previous, version) if FileAccess.file_exists(previous) else {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = parse_quietly(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		set_aside(path)
		var earlier := _read_whole(previous, version)
		if earlier.is_empty():
			push_warning("%s is not valid JSON; starting a new world" % path)
		else:
			push_warning("%s is not valid JSON; went back to the save before it" % path)
		return earlier
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != version:
		push_warning("save file is version %s, expected %d; starting a new world" % [data.get("version"), version])
		set_aside(path)
		return {}
	return data

## The previous copy of a save, if it is whole and of this version; otherwise
## nothing, and the game starts afresh as it would have without one.
static func _read_whole(path: String, version := VERSION) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = parse_quietly(file.get_as_text())
	file.close()
	if parsed is Dictionary and int((parsed as Dictionary).get("version", 0)) == version:
		return parsed
	return {}

## Move a save that cannot be read out of the way, under a name of its own,
## and never delete it.
##
## "Starting a new world" used to mean exactly that, in the same file: twenty
## seconds later the autosave wrote the new, empty valley over the one that
## could not be read. A file that is damaged, or written by a newer copy of the
## game than this one, is still a child's afternoon — a parent can open the JSON
## and see it there, and a later version can read it — so it is kept beside
## the save, and the empty valley goes into a file of its own.
##
## Returns where it was put, or an empty string if it could not be moved.
static func set_aside(path: String) -> String:
	var kept := path + ".unreadable"
	var n := 1
	while FileAccess.file_exists(kept):
		n += 1
		kept = "%s.unreadable-%d" % [path, n]
	var moved := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(kept)
	)
	if moved != OK:
		push_warning("could not keep %s aside: %s" % [path, error_string(moved)])
		return ""
	push_warning("kept the unreadable save as %s" % kept)
	return kept

## Copy a save that is about to be wiped on purpose to a name of its own, and
## return where it went (empty if there was nothing to copy or it failed).
##
## "Start again" is behind a grown-up hold, but a grown-up can hold it by
## mistake, and the next write moves the old valley into `.previous` for only
## one autosave: twenty seconds later it is gone. Each call makes a new
## numbered file and never overwrites an earlier one, so a second reset cannot
## replace the kept valley with the empty one.
static func keep_copy(path: String, label := "before-reset") -> String:
	if not FileAccess.file_exists(path):
		return ""
	var kept := "%s.%s" % [path, label]
	var n := 1
	while FileAccess.file_exists(kept):
		n += 1
		kept = "%s.%s-%d" % [path, label, n]
	if DirAccess.copy_absolute(
		ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(kept)
	) != OK:
		push_warning("could not keep a copy of %s" % path)
		return ""
	return kept

## The contents of a JSON document, or null if it is not one.
##
## Asked of a JSON object rather than of JSON.parse_string, which prints an
## engine error for a document it cannot read. A damaged save is a thing this
## file expects and deals with, and an error in the log for it teaches whoever
## reads the log to read past errors.
static func parse_quietly(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

## A whole number out of a value read from a save, or `fallback`.
##
## `int(x)` is an engine error, not a zero, for null, a list or a table, and the
## error ends the function it is in: a bag file with one bad count lost every
## item listed after it, and the autosave then wrote the shortened bag over the
## file. Numbers and numeric text are taken; anything else is `fallback`.
static func as_int(value: Variant, fallback := 0) -> int:
	if value is int:
		return value
	if value is float or (value is String and (value as String).is_valid_float()):
		var number := float(value)
		if is_finite(number):
			return int(clampf(number, -9.0e15, 9.0e15))
	return fallback

## `as_int` for a decimal number; never NaN or infinite.
static func as_float(value: Variant, fallback := 0.0) -> float:
	if value is int or value is float or (value is String and (value as String).is_valid_float()):
		var number := float(value)
		if is_finite(number):
			return number
	return fallback

## `bool()` that does not stop on a list or a table: true and false, 1 and 0
## are taken, anything else is `fallback`.
static func as_bool(value: Variant, fallback := false) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return as_float(value) != 0.0
	return fallback

static func absolute_path(path := PATH) -> String:
	return ProjectSettings.globalize_path(path)

## Move a pre-profiles save into a named profile, once, so that the valley a
## child built before this existed is still theirs. Returns true if anything was
## moved.
static func migrate_legacy(destination: String) -> bool:
	if not FileAccess.file_exists(PATH) or FileAccess.file_exists(destination):
		return false
	var existing := read()
	if existing.is_empty():
		return false
	if not write(existing, destination):
		return false
	# Renamed rather than deleted: if anything about this went wrong, the
	# original is still sitting there to be recovered by hand.
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(PATH),
		ProjectSettings.globalize_path(PATH + ".migrated")
	)
	return true
