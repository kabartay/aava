class_name Text
extends RefCounted

## Every word the game says, in every language it says it in.
##
## Godot has its own translation system, which expects .po files and a build
## step. This is a dictionary instead, for one reason: the strings are few, they
## are all here, and a parent who wants to fix a clumsy Russian phrase can open
## one file and read it. A .po pipeline would be the correct choice for a
## thousand strings and a translation agency; it is the wrong one for forty
## strings and a father.
##
## Keys are lower-case identifiers rather than English text. Using English as
## the key looks tidy until the English wording changes and every other language
## silently falls back to it.

const EN := &"en"
const FR := &"fr"
const RU := &"ru"

const LANGUAGES: Array[StringName] = [EN, FR, RU]

## What each language calls itself. A child picking a language recognises
## "Русский", not "Russian".
const ENDONYM := {
	EN: "English",
	FR: "Français",
	RU: "Русский",
}

static var _language: StringName = EN

## Every string, keyed by meaning. The French and Russian are written for a
## child to read aloud, not for a manual: short lines, ordinary words, and the
## same register as the English.
const STRINGS := {
	# Items, as they appear in the bag.
	"item_stick": {EN: "stick", FR: "bâton", RU: "палка"},
	"item_stone": {EN: "stone", FR: "pierre", RU: "камень"},
	"item_reed": {EN: "reed", FR: "roseau", RU: "тростник"},
	"item_seed": {EN: "seed", FR: "graine", RU: "семечко"},
	"item_cone": {EN: "cone", FR: "pomme de pin", RU: "шишка"},

	# Things you can build.
	"build_sapling": {EN: "sapling", FR: "jeune arbre", RU: "саженец"},
	"build_feeder": {EN: "feeder", FR: "mangeoire", RU: "кормушка"},
	"build_path": {EN: "path", FR: "sentier", RU: "дорожка"},
	"build_fence": {EN: "fence", FR: "clôture", RU: "забор"},
	"build_campfire": {EN: "campfire", FR: "feu de camp", RU: "костёр"},

	# House parts.
	"part_wall": {EN: "wall", FR: "mur", RU: "стена"},
	"part_wall_door": {EN: "door", FR: "porte", RU: "дверь"},
	"part_wall_window": {EN: "window", FR: "fenêtre", RU: "окно"},
	"part_floor": {EN: "floor", FR: "plancher", RU: "пол"},
	"part_roof": {EN: "roof", FR: "toit", RU: "крыша"},
	"part_roof_peak": {EN: "peak", FR: "faîte", RU: "конёк"},
	"part_stairs": {EN: "stairs", FR: "escalier", RU: "лестница"},
	"part_post": {EN: "post", FR: "poteau", RU: "столб"},

	# Buttons.
	"ui_bag": {EN: "bag", FR: "sac", RU: "рюкзак"},
	"ui_build": {EN: "build", FR: "bâtir", RU: "строить"},
	"ui_close": {EN: "x", FR: "x", RU: "x"},
	"ui_jump": {EN: "jump", FR: "sauter", RU: "прыжок"},
	"ui_kick": {EN: "kick", FR: "tirer", RU: "удар"},
	"ui_things": {EN: "things", FR: "objets", RU: "вещи"},
	"ui_house": {EN: "house", FR: "maison", RU: "дом"},
	"ui_language": {EN: "language", FR: "langue", RU: "язык"},
	"ui_reset": {EN: "start again", FR: "recommencer", RU: "начать заново"},
	"ui_reset_hold": {
		EN: "hold to erase",
		FR: "maintenir pour effacer",
		RU: "держи, чтобы стереть",
	},
	"ui_reset_holding": {EN: "keep holding…", FR: "continue…", RU: "держи…"},
	"say_reset": {
		EN: "the valley is new again",
		FR: "la vallée est neuve",
		RU: "долина снова новая",
	},

	# Why a build was refused.
	"why_wet": {EN: "too wet", FR: "trop mouillé", RU: "слишком мокро"},
	"why_steep": {EN: "too steep", FR: "trop pentu", RU: "слишком круто"},
	"why_no_room": {EN: "no room", FR: "pas de place", RU: "нет места"},
	# %s is the list of missing materials.
	"why_need": {EN: "need %s", FR: "il faut %s", RU: "нужно %s"},

	# Aiming a kick.
	"aim_ground": {EN: "along the ground", FR: "au ras du sol", RU: "низом"},
	"aim_over": {EN: "up and over", FR: "en cloche", RU: "повыше"},
	"aim_high": {EN: "high over the top", FR: "très haut", RU: "высоко навесом"},

	# Things the world says back.
	"say_goal": {EN: "GOAL", FR: "BUT", RU: "ГОЛ"},
	"say_grown": {EN: "your tree has grown", FR: "ton arbre a poussé", RU: "твоё дерево выросло"},
	"say_grove": {
		EN: "a grove — and the birds have found it",
		FR: "un bosquet — les oiseaux l'ont trouvé",
		RU: "роща — и птицы её нашли",
	},
	# %d is how many rocks have been cleared in total.
	"say_cleared": {EN: "cleared it — %d", FR: "franchi — %d", RU: "перепрыгнул — %d"},
	"say_not_here": {EN: "not here", FR: "pas ici", RU: "не сюда"},
	"say_nothing_here": {
		EN: "nothing to take down here",
		FR: "rien à démonter ici",
		RU: "тут нечего разбирать",
	},
	# %s is the name of the piece.
	"say_took_back": {EN: "took the %s back", FR: "%s récupéré", RU: "%s разобрано"},
}

static func language() -> StringName:
	return _language

static func set_language(code: StringName) -> void:
	if LANGUAGES.has(code):
		_language = code

## Look a string up. Falls back to English rather than to the key, because an
## untranslated word a child can still read beats a raw identifier on screen.
static func of(key: String) -> String:
	var entry = STRINGS.get(key)
	if entry == null:
		# Not silently swallowed: a missing key is a bug, and the checks look
		# for exactly this shape on screen.
		push_warning("no text for '%s'" % key)
		return "?" + key
	return entry.get(_language, entry[EN])

## The same, with arguments — so a caller never has to remember which strings
## take a value and format them by hand in two places.
static func format(key: String, values: Array) -> String:
	return Text.of(key) % values
