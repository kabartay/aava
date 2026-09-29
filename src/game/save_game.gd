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

static func write(data: Dictionary, path := PATH) -> bool:
	data["version"] = VERSION
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
	file.store_string(JSON.stringify(data, "\t"))
	# Closed explicitly rather than when the handle happens to fall out of
	# scope, because the rename below must not overtake the last of the bytes.
	file.close()

	var folder_access := DirAccess.open(path.get_base_dir())
	if folder_access == null:
		push_warning("could not reach %s to save into" % path.get_base_dir())
		return false
	var renamed := folder_access.rename(scratch.get_file(), path.get_file())
	if renamed != OK:
		push_warning("could not put %s in place: %s" % [path, error_string(renamed)])
		return false
	return true

static func read(path := PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("%s is not valid JSON; starting a new world" % path)
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		push_warning("save file is version %s, expected %d; starting a new world" % [data.get("version"), VERSION])
		return {}
	return data

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
