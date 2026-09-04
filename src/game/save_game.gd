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
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("could not write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
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
