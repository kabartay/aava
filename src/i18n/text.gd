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
	"ui_settings": {EN: "settings", FR: "réglages", RU: "настройки"},
	"ui_back": {EN: "back", FR: "retour", RU: "назад"},
	"ui_danger": {EN: "for a grown-up", FR: "pour un adulte", RU: "для взрослого"},
	"ui_reset_warning": {
		EN: "this erases everything both of you built",
		FR: "ceci efface tout ce que vous avez bâti",
		RU: "это сотрёт всё, что вы построили вдвоём",
	},
	"ui_reset_hold": {
		EN: "hold to erase",
		FR: "maintenir pour effacer",
		RU: "держи, чтобы стереть",
	},
	"ui_reset_holding": {EN: "keep holding…", FR: "continue…", RU: "держи…"},
	# The opening steps. Each is a single instruction with one verb, phrased as
	# something to go and do rather than something to understand.
	"task_gather": {
		EN: "find 3 sticks in the grass",
		FR: "trouve 3 bâtons dans l'herbe",
		RU: "найди 3 палки в траве",
	},
	"task_gather_done": {
		EN: "you can carry things — look in your bag",
		FR: "tu peux porter des choses — regarde ton sac",
		RU: "ты можешь носить вещи — загляни в рюкзак",
	},
	"task_build": {
		EN: "tap build, then put a path stone down",
		FR: "appuie sur bâtir, puis pose une dalle",
		RU: "нажми строить и положи дорожку",
	},
	"task_build_done": {
		EN: "anything you build, you can take back",
		FR: "tout ce que tu bâtis, tu peux le reprendre",
		RU: "всё, что построил, можно разобрать",
	},
	"task_pitch": {
		EN: "there is a football pitch west of here",
		FR: "il y a un terrain de football à l'ouest",
		RU: "к западу отсюда есть футбольное поле",
	},
	"task_pitch_done": {
		EN: "hold kick to shoot — look up to lift it",
		FR: "maintiens tirer — lève les yeux pour lober",
		RU: "держи удар — смотри вверх, чтобы навесить",
	},
	"task_plant": {
		EN: "plant 3 saplings close together",
		FR: "plante 3 jeunes arbres côte à côte",
		RU: "посади 3 саженца рядом",
	},
	"task_plant_done": {
		EN: "wait, and the birds will come",
		FR: "attends, les oiseaux viendront",
		RU: "подожди — прилетят птицы",
	},
	"task_free": {
		EN: "the valley is yours",
		FR: "la vallée est à toi",
		RU: "долина твоя",
	},

	# Animals, and what they are asking for.
	"animal_cat": {EN: "cat", FR: "chat", RU: "кошка"},
	"animal_dog": {EN: "dog", FR: "chien", RU: "собака"},
	"animal_squirrel": {EN: "squirrel", FR: "écureuil", RU: "белка"},
	"animal_beaver": {EN: "beaver", FR: "castor", RU: "бобр"},
	"wish_stroke": {EN: "wants a stroke", FR: "veut une caresse", RU: "хочет, чтобы её погладили"},
	"wish_give": {EN: "wants a %s", FR: "veut %s", RU: "хочет %s"},
	"say_fed": {EN: "+%d", FR: "+%d", RU: "+%d"},
	"say_friend": {
		EN: "%s is your friend now",
		FR: "%s est ton ami maintenant",
		RU: "%s теперь твой друг",
	},

	# The shop, and what each thing is for. Descriptions say what it does rather
	# than what it is, because a child buys a verb.
	"back_built": {
		EN: "Last time you built %d things",
		FR: "La dernière fois tu as construit %d choses",
		RU: "В прошлый раз ты построил: %d",
	},
	"back_cared": {
		EN: "Last time you looked after %d animals",
		FR: "La dernière fois tu t'es occupé de %d animaux",
		RU: "В прошлый раз ты позаботился о зверях: %d",
	},
	"back_goals": {
		EN: "Last time you scored %d goals",
		FR: "La dernière fois tu as marqué %d buts",
		RU: "В прошлый раз ты забил голов: %d",
	},
	"back_planted": {
		EN: "Last time you planted %d trees",
		FR: "La dernière fois tu as planté %d arbres",
		RU: "В прошлый раз ты посадил деревьев: %d",
	},
	"back_rocks": {
		EN: "Last time you cleared %d rocks",
		FR: "La dernière fois tu as sauté %d rochers",
		RU: "В прошлый раз ты перепрыгнул камней: %d",
	},
	"back_coins": {
		EN: "Last time you earned %d coins",
		FR: "La dernière fois tu as gagné %d pièces",
		RU: "В прошлый раз ты заработал монет: %d",
	},
	"back_grown": {
		EN: "Your trees grew while you were away",
		FR: "Tes arbres ont poussé pendant ton absence",
		RU: "Твои деревья подросли, пока тебя не было",
	},
	"back_welcome": {
		EN: "Welcome back", FR: "Bon retour", RU: "С возвращением",
	},
	"ui_whistle": {
		EN: "whistle", FR: "siffler", RU: "свистнуть",
	},
	"say_whistled": {
		EN: "they heard you", FR: "ils t'ont entendu", RU: "тебя услышали",
	},
	"ui_drink": {
		EN: "drink", FR: "boire", RU: "попить",
	},
	"say_filled": {
		EN: "bottle full", FR: "gourde pleine", RU: "бутылка полная",
	},
	"say_tired": {
		EN: "too tired to run — rest, or have a drink",
		FR: "trop fatigué pour courir — repose-toi, ou bois un coup",
		RU: "устал бежать — отдохни или попей",
	},
	"say_rested": {
		EN: "you can run again", FR: "tu peux courir à nouveau",
		RU: "снова можно бежать",
	},
	"say_watered": {
		EN: "%s had a drink", FR: "%s a bu", RU: "%s попил",
	},
	"ui_shop": {EN: "shop", FR: "boutique", RU: "магазин"},
	"ui_coins": {EN: "coins", FR: "pièces", RU: "монеты"},
	"ui_owned": {EN: "yours", FR: "à toi", RU: "твоё"},
	"say_bought": {EN: "%s is yours", FR: "%s est à toi", RU: "%s теперь твой"},
	"say_too_dear": {
		EN: "not enough coins yet",
		FR: "pas encore assez de pièces",
		RU: "пока не хватает монет",
	},
	"shop_bottle": {EN: "water bottle", FR: "gourde", RU: "фляга"},
	"shop_bottle_what": {
		EN: "carry water, and give animals a drink",
		FR: "porte de l'eau et fais boire les animaux",
		RU: "носи воду и пои животных",
	},
	"shop_axe": {EN: "axe", FR: "hache", RU: "топор"},
	"shop_axe_what": {
		EN: "fell a tree for its wood",
		FR: "abats un arbre pour son bois",
		RU: "сруби дерево ради древесины",
	},
	"shop_lantern": {EN: "lantern", FR: "lanterne", RU: "фонарь"},
	"shop_lantern_what": {
		EN: "see in the dark",
		FR: "vois dans le noir",
		RU: "видеть в темноте",
	},
	"shop_whistle": {EN: "whistle", FR: "sifflet", RU: "свисток"},
	"shop_whistle_what": {
		EN: "your friends come when you call",
		FR: "tes amis viennent quand tu appelles",
		RU: "друзья приходят на зов",
	},
	"shop_bicycle": {EN: "bicycle", FR: "vélo", RU: "велосипед"},
	"shop_bicycle_what": {
		EN: "ride instead of walking",
		FR: "roule au lieu de marcher",
		RU: "катайся вместо ходьбы",
	},

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

	# Which storey the ghost is on. %d counts from 1 for the ground floor,
	# because "floor 0" means nothing to a child.
	"ui_ground_floor": {EN: "ground floor", FR: "rez-de-chaussée", RU: "первый этаж"},
	"ui_upper_floor": {EN: "floor %d", FR: "étage %d", RU: "этаж %d"},
	"ui_go_up_hint": {
		EN: "stand higher to build higher",
		FR: "monte pour bâtir plus haut",
		RU: "встань выше — построишь выше",
	},

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
