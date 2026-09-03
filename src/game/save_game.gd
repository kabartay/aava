class_name SaveGame
extends RefCounted

## Reading and writing the one save file.
##
## Plain JSON rather than a Godot resource, for a reason that matters in a
## family project: when something goes wrong, a parent can open the file, read
## it, and see that his child's afternoon of building is still in there. A
## binary resource offers no such reassurance, and loading one runs whatever
## script it names.

const PATH := "user://aava-save.json"

## Bumped whenever the shape of the file changes. Old saves are then migrated or
## refused explicitly, rather than crashing on a missing key.
const VERSION := 1

static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("could not write %s: %s" % [PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true

static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("%s is not valid JSON; starting a new world" % PATH)
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		push_warning("save file is version %s, expected %d; starting a new world" % [data.get("version"), VERSION])
		return {}
	return data

static func absolute_path() -> String:
	return ProjectSettings.globalize_path(PATH)
