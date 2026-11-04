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

## Circassian — Adyghe and Kabardian, which are the same language written the
## same way either side of a border.
##
## Being written. Every string it does not have yet falls back to Russian
## rather than to English: this is the language of a place where Russian is the
## one everybody also reads, and a half-translated game that falls back to
## English there would be less use, not more. Nothing here is guessed — a
## string arrives when somebody who speaks it writes it.
const AD := &"ad"

const LANGUAGES: Array[StringName] = [EN, FR, RU, AD]

## The languages that must be complete. Circassian is left out of it while it
## is being filled in, and its fallback keeps the game entirely playable
## meanwhile — but every other language has to answer for every string, which
## is the check that has caught missing translations before.
const FINISHED_LANGUAGES: Array[StringName] = [EN, FR, RU]

## What each language calls itself. A child picking a language recognises
## "Русский", not "Russian".
const ENDONYM := {
	EN: "English",
	FR: "Français",
	RU: "Русский",
	AD: "Адыгэбзэ",
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
	"item_chocolate": {EN: "chocolate", FR: "chocolat", RU: "шоколадка"},
	"item_wool": {EN: "wool", FR: "laine", RU: "шерсть"},
	"item_wood": {EN: "wood", FR: "bois", RU: "древесина"},
	"item_wood_object": {EN: "wood", FR: "du bois", RU: "древесину"},
	"item_wool_object": {EN: "wool", FR: "de la laine", RU: "шерсть"},
	"item_chocolate_object": {EN: "chocolate", FR: "du chocolat", RU: "шоколадку"},
	# The same items as the object of a verb — "wants a stick" — which in
	# Russian is a different form of the word. English and French do not
	# decline, so those repeat the name; the key exists so that every
	# language has somewhere to put its accusative.
	"item_stick_object": {EN: "stick", FR: "un bâton", RU: "палку"},
	"item_stone_object": {EN: "stone", FR: "une pierre", RU: "камень"},
	"item_reed_object": {EN: "reed", FR: "un roseau", RU: "тростник"},
	"item_seed_object": {EN: "seed", FR: "une graine", RU: "семечко"},
	"item_cone_object": {EN: "cone", FR: "une pomme de pin", RU: "шишку"},

	# Things you can build.
	"build_sapling": {EN: "sapling", FR: "jeune arbre", RU: "саженец"},
	"build_pine": {EN: "fir", FR: "sapin", RU: "ёлка"},
	"part_bed": {EN: "bed", FR: "lit", RU: "кровать"},
	"ui_sleep": {
		EN: "sleep", FR: "dormir", RU: "спать",
	},
	"say_slept": {
		EN: "morning already — you slept well",
		FR: "déjà le matin — tu as bien dormi",
		RU: "уже утро — хорошо спалось!",
	},
	"say_not_tired": {
		EN: "it is daylight — there is a whole valley out there",
		FR: "il fait jour — toute une vallée t'attend",
		RU: "сейчас день — вон целая долина ждёт",
	},
	# Shown when a child falls out of the world and is put back on top of it.
	# main.gd asked for this key and nothing here answered, so what a child
	# actually saw at the worst possible moment was the literal "?say_caught".
	"say_caught": {
		EN: "caught you — back on solid ground",
		FR: "on t'a rattrapé — te revoilà sur la terre ferme",
		RU: "поймали — снова на твёрдой земле",
	},
	"ui_feed_fire": {
		EN: "add wood", FR: "mettre du bois", RU: "подбросить дров",
	},
	"say_fire_fed": {
		EN: "burning for %d more min",
		FR: "brûle encore %d min",
		RU: "горит ещё %d мин",
	},
	"say_fire_out": {
		EN: "the fire went out", FR: "le feu s'est éteint", RU: "костёр погас",
	},
	"say_felled_cost": {
		EN: "+%d wood, but the tree is gone: −%d",
		FR: "+%d bois, mais l'arbre n'est plus là : −%d",
		RU: "древесина: +%d, но дерева больше нет: −%d",
	},
	"say_grown_fir": {
		EN: "your fir is grown! +%d", FR: "ton sapin a poussé ! +%d",
		RU: "ёлка выросла! +%d",
	},
	"say_grown_tree": {
		EN: "your tree is grown! +%d", FR: "ton arbre a poussé ! +%d",
		RU: "дерево выросло! +%d",
	},
	"build_feeder": {EN: "feeder", FR: "mangeoire", RU: "кормушка"},
	"build_path": {EN: "path", FR: "sentier", RU: "дорожка"},
	"build_fence": {EN: "fence", FR: "clôture", RU: "забор"},
	"build_campfire": {EN: "campfire", FR: "feu de camp", RU: "костёр"},

	# House parts.
	"part_wall": {EN: "wall", FR: "mur", RU: "стена"},
	"part_wall_door": {EN: "door", FR: "porte", RU: "дверь"},
	"part_wall_window": {EN: "window", FR: "fenêtre", RU: "окно"},
	"part_floor": {EN: "floor", FR: "plancher", RU: "пол"},
	# The single-slope roof square. Called "roof" while it was the only roof,
	# it now sits in the roof group beside the whole roof, and three buttons
	# reading roof, peak and roof said nothing about which was which.
	"part_roof": {EN: "slope", FR: "pente", RU: "скат"},
	"part_roof_peak": {EN: "peak", FR: "faîte", RU: "конёк"},
	# The roof that covers a whole room in one tap. Short, because it is
	# written under a picture on a button a thumb wide.
	"part_roof_room": {EN: "whole roof", FR: "toit entier", RU: "вся крыша"},
	"part_stairs": {EN: "stairs", FR: "escalier", RU: "лестница"},
	"part_post": {EN: "post", FR: "poteau", RU: "столб"},
	# The pieces that make a shop, a cafe or a proper house. Short, because each
	# is written under a picture on a button a thumb wide.
	"part_wall_wide": {EN: "wide window", FR: "vitrine", RU: "витрина"},
	"part_wall_half": {EN: "half wall", FR: "muret", RU: "низкая стена"},
	"part_wall_arch": {EN: "arch", FR: "arche", RU: "арка"},
	"part_roof_flat": {EN: "flat roof", FR: "toit plat", RU: "плоская крыша"},
	"part_chimney": {EN: "chimney", FR: "cheminée", RU: "труба"},
	"part_table": {EN: "table", FR: "table", RU: "стол"},
	"part_chair": {EN: "chair", FR: "chaise", RU: "стул"},
	"part_counter": {EN: "counter", FR: "comptoir", RU: "прилавок"},
	"part_shelf": {EN: "shelf", FR: "étagère", RU: "полка"},
	"part_lamp": {EN: "lamp", FR: "lampe", RU: "лампа"},
	"part_sign": {EN: "sign", FR: "enseigne", RU: "вывеска"},
	"part_pot": {EN: "flower pot", FR: "pot de fleurs", RU: "цветок"},
	"part_rug": {EN: "rug", FR: "tapis", RU: "ковёр"},
	# The ready-made plans, which go up in one tap.
	"build_plan_room": {EN: "room", FR: "pièce", RU: "комната"},
	"build_plan_house": {EN: "house", FR: "maison", RU: "дом"},
	"build_plan_cafe": {EN: "cafe", FR: "café", RU: "кафе"},
	"build_plan_shop": {EN: "shop", FR: "boutique", RU: "магазин"},
	"ui_group_plans": {EN: "plans", FR: "plans", RU: "планы"},
	# What a wall can be made of, on the one button that chooses.
	"ui_material_plaster": {EN: "plaster", FR: "crépi", RU: "штукатурка"},
	"ui_material_stone": {EN: "stone", FR: "pierre", RU: "камень"},
	"ui_material_blue": {EN: "blue", FR: "bleu", RU: "синий"},
	"ui_material_red": {EN: "red", FR: "rouge", RU: "красный"},
	# What a child's own cafe asks for a meal when it asks nothing.
	"ui_cafe_free": {EN: "free", FR: "gratuit", RU: "бесплатно"},
	# Said once, when a building first becomes a cafe or a shop.
	"say_own_cafe": {
		EN: "your cafe is open — sit at a table and eat",
		FR: "ton café est ouvert — assieds-toi à une table et mange",
		RU: "твоё кафе открыто — садись за стол и ешь",
	},
	"say_own_shop": {
		EN: "your shop is open — sell your wool at the counter",
		FR: "ta boutique est ouverte — vends ta laine au comptoir",
		RU: "твой магазин открыт — продавай шерсть у прилавка",
	},
	"say_nothing_to_sell": {
		EN: "nothing to sell yet", FR: "rien à vendre pour l'instant", RU: "пока нечего продавать",
	},

	# Buttons.
	"ui_things": {EN: "things", FR: "objets", RU: "вещи"},
	# The groups of the build palette, written small under each group's picture.
	"ui_group_walls": {EN: "walls", FR: "murs", RU: "стены"},
	"ui_group_floor": {EN: "floor", FR: "sol", RU: "пол"},
	"ui_group_roof": {EN: "roof", FR: "toit", RU: "крыша"},
	"ui_group_furniture": {EN: "furniture", FR: "meubles", RU: "мебель"},
	"ui_language": {EN: "language", FR: "langue", RU: "язык"},
	# Who is playing. The name a child types here is the name that floats over
	# their head in somebody else's valley, which is the whole reason to ask
	# for one: "Игрок" above a brother tells you nothing you did not know.
	"ui_your_name": {EN: "your name", FR: "ton prénom", RU: "твоё имя"},
	"ui_name_hint": {EN: "tap to type it", FR: "appuie pour écrire", RU: "нажми и напиши"},
	# Said when the phone will not let the game use its microphone. Where to go
	# is spelt out because after two refusals Android stops asking, and the
	# only way back is the phone's own settings.
	"say_mic_refused": {
		EN: "I can't hear you: the microphone is off. To allow it, open the phone's Settings, then Apps, Aava, Permissions, Microphone.",
		FR: "Je ne t'entends pas : le micro est coupé. Pour l'autoriser, ouvre les Réglages du téléphone, puis Applications, Aava, Autorisations, Micro.",
		RU: "Тебя не слышно: микрофон выключен. Чтобы разрешить, открой Настройки телефона, потом Приложения, Aava, Разрешения, Микрофон.",
	},
	# Who a child is drawn as. Every choice is a picture; these words are for the
	# grown-up reading over a shoulder and for the one title of the panel that a
	# first run opens, which a child understands from the faces on it.
	"ui_who_are_you": {EN: "who are you?", FR: "qui es-tu ?", RU: "кто ты?"},
	"ui_char_simple": {EN: "round friend", FR: "petit rond", RU: "круглый друг"},
	"ui_char_boy": {EN: "boy", FR: "garçon", RU: "мальчик"},
	"ui_char_girl": {EN: "girl with pigtails", FR: "fille aux couettes", RU: "девочка с хвостиками"},
	"ui_char_cap": {EN: "cap and dungarees", FR: "casquette et salopette", RU: "кепка и комбинезон"},
	"ui_char_bear": {EN: "little bear", FR: "petit ours", RU: "медвежонок"},
	"say_name_set": {
		EN: "hello, %s — that is the name they will see",
		FR: "bonjour %s — c'est le nom qu'ils verront",
		RU: "привет, %s — это имя они и увидят",
	},
	"say_name_no": {
		EN: "letters, numbers and spaces, up to 16",
		FR: "lettres, chiffres et espaces, 16 au plus",
		RU: "буквы, цифры и пробелы, не больше 16",
	},
	"ui_back": {EN: "back", FR: "retour", RU: "назад"},
	"ui_danger": {EN: "for a grown-up", FR: "pour un adulte", RU: "для взрослого"},
	"ui_reset_warning": {
		EN: "this erases everything both of you built",
		FR: "ceci efface tout ce que vous avez bâti",
		RU: "это сотрёт всё, что вы построили вдвоём",
	},
	"ui_reset_hold": {
		EN: "hold to erase",
		FR: "maintiens pour effacer",
		RU: "держи, чтобы стереть",
	},
	"ui_reset_holding": {EN: "keep holding…", FR: "continue…", RU: "держи…"},
	# Said when a button that has to be held is only tapped.
	"ui_hold_hint": {
		EN: "press and hold",
		FR: "appuie longtemps",
		RU: "нажми и держи",
	},
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
		RU: "всё, что ты строишь, можно разобрать",
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

	# Animals, and what they are asking for.
	"animal_cat": {EN: "cat", FR: "chat", RU: "кошка"},
	"animal_dog": {EN: "dog", FR: "chien", RU: "собака"},
	"animal_squirrel": {EN: "squirrel", FR: "écureuil", RU: "белка"},
	"animal_sheep": {EN: "sheep", FR: "mouton", RU: "овца"},
	"animal_cow": {EN: "cow", FR: "vache", RU: "корова"},
	"animal_beaver": {EN: "beaver", FR: "castor", RU: "бобр"},
	"wish_shear": {EN: "can be sheared", FR: "peut être tondu", RU: "можно постричь"},
	"wish_milk": {EN: "has milk to spare", FR: "a du lait", RU: "можно подоить"},
	"wish_stroke": {EN: "wants a stroke", FR: "veut une caresse", RU: "хочет, чтобы погладили"},
	# The item goes in as its object form — Russian declines it: "хочет палку".
	"wish_give": {EN: "wants a %s", FR: "veut %s", RU: "хочет %s"},
	"wish_drink": {EN: "%s is thirsty", FR: "%s a soif", RU: "%s хочет пить"},
	"wish_resting": {EN: "resting", FR: "se repose", RU: "отдыхает"},
	"wish_not_tired": {EN: "you are not tired", FR: "tu n'es pas fatigué", RU: "ты не устал"},
	"need_shears": {EN: "needs shears", FR: "il faut des ciseaux", RU: "нужны ножницы"},
	# The item as an object: "bring a stick", "принеси палку".
	"need_give": {EN: "bring a %s", FR: "apporte %s", RU: "принеси %s"},
	"say_fed": {EN: "+%d", FR: "+%d", RU: "+%d"},
	"say_friend": {
		EN: "%s is your friend now",
		FR: "%s et toi, vous êtes amis",
		RU: "%s теперь твой друг",
	},

	# The shop, and what each thing is for. Descriptions say what it does rather
	# than what it is, because a child buys a verb.
	"back_built": {
		EN: "Last time you built %d{thing|things}",
		FR: "La dernière fois tu as construit %d{chose|choses}",
		RU: "В прошлый раз построено: %d",
	},
	"back_cared": {
		EN: "Last time you looked after %d{animal|animals}",
		FR: "La dernière fois tu t'es occupé de %d{animal|animaux}",
		RU: "В прошлый раз о зверях позаботились: %d",
	},
	"back_goals": {
		EN: "Last time you scored %d{goal|goals}",
		FR: "La dernière fois tu as marqué %d{but|buts}",
		RU: "В прошлый раз забито голов: %d",
	},
	"back_planted": {
		EN: "Last time you planted %d{tree|trees}",
		FR: "La dernière fois tu as planté %d{arbre|arbres}",
		RU: "В прошлый раз посажено деревьев: %d",
	},
	"back_rocks": {
		EN: "Last time you cleared %d{rock|rocks}",
		FR: "La dernière fois tu as sauté %d{rocher|rochers}",
		RU: "В прошлый раз перепрыгнуто камней: %d",
	},
	"back_coins": {
		EN: "Last time you earned %d{coin|coins}",
		FR: "La dernière fois tu as gagné %d{pièce|pièces}",
		RU: "В прошлый раз заработано монет: %d",
	},
	"back_grown": {
		EN: "Your trees grew while you were away",
		FR: "Tes arbres ont poussé pendant ton absence",
		RU: "Твои деревья подросли, пока тебя не было",
	},
	"today_visit": {
		EN: "Today: come and see the valley",
		FR: "Aujourd'hui : viens voir la vallée",
		RU: "Сегодня: приходи посмотреть на долину",
	},
	"today_care": {
		EN: "Today: look after %d{animal|animals} more",
		FR: "Aujourd'hui : occupe-toi encore de %d{animal|animaux}",
		RU: "Сегодня: позаботься о зверях — осталось %d",
	},
	"today_build": {
		EN: "Today: build %d{piece|pieces} more",
		FR: "Aujourd'hui : construis encore %d{pièce|pièces}",
		RU: "Сегодня: построй ещё деталей — %d",
	},
	"today_score": {
		EN: "Today: score %d{goal|goals} more",
		FR: "Aujourd'hui : marque encore %d{but|buts}",
		RU: "Сегодня: забей ещё голов — %d",
	},
	"today_shoot": {
		EN: "Today: hit the target %d{time|times} more",
		FR: "Aujourd'hui : touche les cibles encore %d fois",
		RU: "Сегодня: попади по мишеням ещё %d{раз|раза|раз}",
	},
	"today_plant": {
		EN: "Today: plant %d{tree|trees} more",
		FR: "Aujourd'hui : plante encore %d{arbre|arbres}",
		RU: "Сегодня: посади ещё деревьев — %d",
	},
	"today_done": {
		EN: "Today's thing is done", FR: "C'est fait pour aujourd'hui",
		RU: "На сегодня всё сделано",
	},
	"say_basket": {
		EN: "Basket!", FR: "Panier !", RU: "Попал!",
	},
	"say_today": {
		EN: "done for today! +%d", FR: "fait pour aujourd'hui ! +%d",
		RU: "на сегодня готово! +%d",
	},
	"say_dam_stick": {
		EN: "the beavers take it — %d more",
		FR: "les castors le prennent — encore %d",
		RU: "бобры взяли — ещё %d",
	},
	"say_dam_done": {
		EN: "the beavers finished the dam!",
		FR: "les castors ont fini le barrage !",
		RU: "бобры достроили запруду!",
	},
	"ui_talk": {
		EN: "talk", FR: "parler", RU: "говорить",
	},
	"ui_player": {
		EN: "player", FR: "joueur", RU: "игрок",
	},
	"ui_together": {
		EN: "play together", FR: "jouer ensemble", RU: "играть вместе",
	},
	"ui_invite": {
		EN: "invite someone", FR: "inviter quelqu'un", RU: "позвать к себе",
	},
	"ui_visit": {
		EN: "go to someone", FR: "aller chez quelqu'un", RU: "пойти к другому",
	},
	"ui_your_number": {
		EN: "your number", FR: "ton numéro", RU: "твой номер",
	},
	"ui_their_number": {
		EN: "their number", FR: "son numéro", RU: "его номер",
	},
	"ui_play_alone": {
		EN: "play alone again", FR: "rejouer tout seul", RU: "играть в одиночку",
	},
	"say_read_it_out": {
		EN: "tell it to the other player, and they can come to your valley",
		FR: "dis-le à l'autre joueur, il pourra venir dans ta vallée",
		RU: "скажи этот номер другому — он придёт в твою долину",
	},
	"say_no_network": {
		EN: "this device is not on a network",
		FR: "cet appareil n'est pas sur un réseau",
		RU: "это устройство не в сети",
	},
	"say_visiting": {
		EN: "you are in someone else's valley",
		FR: "tu es dans la vallée de quelqu'un d'autre",
		RU: "ты в чужой долине",
	},
	"say_hosting": {
		EN: "your valley is open — your number is %d",
		FR: "ta vallée est ouverte — ton numéro est %d",
		RU: "твоя долина открыта — твой номер %d",
	},
	"say_reset_visiting": {
		EN: "you can only start again in your own valley",
		FR: "tu ne peux recommencer que dans ta propre vallée",
		RU: "начать заново можно только в своей долине",
	},
	"say_alone_again": {
		EN: "playing alone again", FR: "de nouveau tout seul",
		RU: "снова играешь в одиночку",
	},
	"say_joining": {
		EN: "looking for that valley…", FR: "je cherche cette vallée…",
		RU: "ищем эту долину…",
	},
	"say_met": {
		EN: "%s is here", FR: "%s est là", RU: "%s здесь",
	},
	"fail_unreachable": {
		EN: "nobody answered — both phones must be on the same Wi-Fi, and the number must be right",
		FR: "personne n'a répondu — les deux téléphones doivent être sur le même Wi-Fi, et le numéro doit être le bon",
		RU: "никто не ответил — оба телефона должны быть в одной сети Wi-Fi, а номер — верным",
	},
	"say_same_wifi": {
		EN: "both phones must be on the same Wi-Fi",
		FR: "les deux téléphones doivent être sur le même Wi-Fi",
		RU: "оба телефона должны быть в одной сети Wi-Fi",
	},
	"fail_too_big": {
		EN: "that valley is too big to bring over",
		FR: "cette vallée est trop grande pour être apportée",
		RU: "эта долина слишком большая, чтобы её перенести",
	},
	"fail_host_closed": {
		EN: "your friend closed their valley",
		FR: "ton ami a fermé sa vallée",
		RU: "друг закрыл свою долину",
	},
	"fail_in_use": {
		EN: "the game is already open on this device",
		FR: "le jeu est déjà ouvert sur cet appareil",
		RU: "игра уже открыта на этом устройстве",
	},
	"fail_open": {
		EN: "could not open the valley", FR: "impossible d'ouvrir la vallée",
		RU: "не удалось открыть долину",
	},
	"fail_connect": {
		EN: "could not connect", FR: "connexion impossible",
		RU: "не удалось подключиться",
	},
	"say_joined": {
		EN: "%s came to your valley", FR: "%s a rejoint ta vallée",
		RU: "%s теперь у тебя в долине",
	},
	"say_left": {
		EN: "%s went home", FR: "%s rentre à la maison", RU: "%s уходит домой",
	},
	"back_welcome": {
		EN: "Welcome back", FR: "Bon retour", RU: "С возвращением",
	},
	"place_playground": {
		EN: "playground", FR: "aire de jeux", RU: "площадка",
	},
	"place_pool": {
		EN: "pool", FR: "piscine", RU: "бассейн",
	},
	"place_cafe": {
		EN: "cafe", FR: "café", RU: "кафе",
	},
	"place_shop": {EN: "the shop", FR: "la boutique", RU: "магазин"},
	# Region names on the map; the label capitalises the first letter. "map_lake"
	# and "map_fairground" are shared with the legend (see below).
	"map_river": {EN: "river", FR: "rivière", RU: "река"},
	"map_forest": {EN: "forest", FR: "forêt", RU: "лес"},
	"map_mountains": {EN: "mountains", FR: "montagnes", RU: "горы"},
	"say_lantern_on": {EN: "the lantern is lit", FR: "la lanterne est allumée", RU: "фонарь зажжён"},
	"say_lantern_off": {EN: "the lantern is out", FR: "la lanterne est éteinte", RU: "фонарь погашен"},
	"say_sheared": {
		EN: "sheared: +%d wool", FR: "tondu : +%d laine", RU: "острижена: шерсть +%d",
	},
	"say_milk": {
		EN: "fresh milk", FR: "du lait frais", RU: "парное молоко",
	},
	"say_waiting_outside": {
		EN: "your %s is waiting outside the door",
		FR: "%s : ton engin t'attend devant la porte",
		RU: "%s ждёт тебя снаружи у двери",
	},
	"say_sold": {
		EN: "sold %d for %d{coin|coins}", FR: "%d{vendu|vendus} pour %d{pièce|pièces}",
		RU: "продано %d за %d{монету|монеты|монет}",
	},
	# Said when a sale would be paid into a purse with no room left for it.
	"say_purse_full": {
		EN: "your purse is too full for that — spend a few coins first",
		FR: "ta bourse est trop pleine — dépense quelques pièces d'abord",
		RU: "кошелёк слишком полон — сначала потрать немного монет",
	},
	"say_chocolate": {
		EN: "that is better",
		FR: "ça va mieux",
		RU: "так-то лучше",
	},
	# The café's menu: six dishes, each a word under its picture once it has been
	# tapped, and the line that says what it gives.
	"dish_juice": {EN: "juice", FR: "jus d'orange", RU: "сок"},
	"dish_icecream": {EN: "ice cream", FR: "glace", RU: "мороженое"},
	"dish_pancake": {EN: "pancakes", FR: "crêpes", RU: "блинчики"},
	"dish_soup": {EN: "soup", FR: "soupe", RU: "суп"},
	"dish_pizza": {EN: "pizza", FR: "pizza", RU: "пицца"},
	"dish_cake": {EN: "party cake", FR: "gâteau de fête", RU: "праздничный торт"},
	"dish_gives": {EN: "%d%% energy", FR: "%d %% d'énergie", RU: "энергия: %d%%"},
	"dish_cools": {EN: "and cools you down", FR: "et te rafraîchit", RU: "и освежает"},
	"ui_cafe_paid": {EN: "paid", FR: "payant", RU: "платно"},
	"say_ate": {
		EN: "that was good", FR: "c'était bon", RU: "вкусно",
	},
	"say_not_hungry": {
		EN: "not hungry yet", FR: "pas encore faim", RU: "пока не хочется есть",
	},
	"say_no_coins": {
		EN: "you need %d{coin|coins}", FR: "il te faut %d{pièce|pièces}", RU: "нужно монет: %d",
	},
	"say_gold": {
		EN: "gold! +%d", FR: "dans l'or ! +%d", RU: "в золото! +%d",
	},
	"say_hit": {
		EN: "hit! +%d", FR: "touché ! +%d", RU: "попал! +%d",
	},
	"say_missed": {
		EN: "missed — try aiming higher",
		FR: "raté — vise plus haut",
		RU: "мимо — попробуй выше",
	},
	"mount_horse": {
		EN: "horse", FR: "cheval", RU: "конь",
	},
	"mount_bicycle": {
		EN: "bicycle", FR: "vélo", RU: "велосипед",
	},
	"mount_motorcycle": {
		EN: "motorcycle", FR: "moto", RU: "мотоцикл",
	},
	"mount_quad": {
		EN: "quad bike", FR: "quad", RU: "квадроцикл",
	},
	"mount_boat": {
		EN: "boat", FR: "barque", RU: "лодка",
	},
	# "you are riding the horse": Russian wants the mount in the prepositional
	# case after "на".
	"mount_horse_on": {EN: "horse", FR: "à cheval", RU: "на коне"},
	"mount_bicycle_on": {EN: "bicycle", FR: "à vélo", RU: "на велосипеде"},
	"mount_motorcycle_on": {EN: "motorcycle", FR: "à moto", RU: "на мотоцикле"},
	"mount_quad_on": {EN: "quad bike", FR: "en quad", RU: "на квадроцикле"},
	"mount_boat_on": {EN: "boat", FR: "en barque", RU: "на лодке"},
	"say_mounted": {
		# No article in French: the moto and the barque are feminine, and the
		# label is all the sentence has to go on.
		EN: "you are on the %s", FR: "te voilà %s", RU: "ты едешь %s",
	},
	"ui_chop": {
		EN: "chop", FR: "couper", RU: "срубить",
	},
	"say_felled": {
		EN: "timber! +%d wood", FR: "et voilà ! +%d bois", RU: "готово! древесина: +%d",
	},
	"say_whistled": {
		EN: "they heard you", FR: "ils ont entendu ton appel", RU: "тебя услышали",
	},
	"say_filled": {
		EN: "bottle full", FR: "gourde pleine", RU: "фляга полная",
	},
	"say_tired": {
		EN: "too tired to run — rest, or have a drink",
		FR: "plus de souffle pour courir — repose-toi, ou bois un peu",
		RU: "нет сил бежать — отдохни или попей",
	},
	"say_rested": {
		EN: "you can run again", FR: "tu peux courir à nouveau",
		RU: "снова можно бежать",
	},
	"say_watered": {
		# Present tense in Russian: the past agrees with the animal's gender,
		# and three of the four are feminine.
		EN: "%s had a drink", FR: "%s a bu", RU: "%s пьёт",
	},
	"ui_shop": {EN: "shop", FR: "boutique", RU: "магазин"},
	"ui_buy": {EN: "buy", FR: "acheter", RU: "купить"},
	"ui_sell": {EN: "sell", FR: "vendre", RU: "продать"},
	"shop_buys": {
		EN: "the shop buys it, %d{coin|coins} each",
		# Plural in French for every price the shop pays (it pays two), and
		# the count after the noun in Russian, as the other coin texts do:
		# "по 4 монете" is wrong for anything but one.
		FR: "la boutique l'achète, %d{pièce|pièces} l'unité",
		RU: "магазин берёт, монет за штуку: %d",
	},
	"say_bought": {EN: "%s is yours", FR: "%s est à toi", RU: "%s теперь у тебя"},
	# %d is how many of the thing a child may have at once.
	"say_enough_of_those": {
		EN: "you have %d already — go and fetch one",
		FR: "tu en as déjà %d — va rechercher celui que tu as laissé",
		RU: "у тебя их уже %d — сходи за оставленным",
	},
	# %s is the thing, %d what the shop gave for it.
	"say_sold_back": {
		EN: "sold the %s back for %d{coin|coins}",
		FR: "revente : %s, %d{pièce|pièces}",
		RU: "обратно в магазин: %s, монет: %d",
	},
	# %s is the machine. Said when it is standing on ground it cannot be
	# ridden over, so that it is refused before a child gets on rather than a
	# stride afterwards.
	"say_not_ridden_here": {
		EN: "the %s cannot go from here — push it clear first",
		FR: "%s : impossible de partir d'ici — pousse-le sur le côté",
		RU: "%s: отсюда не уехать — отодвинь в сторону",
	},
	# Said to the child who got on a machine at the very moment the other one
	# did and was the one to get down again: the host's child keeps it.
	"say_mount_taken": {
		EN: "your friend got on it first",
		FR: "ton ami est monté dessus le premier",
		RU: "твой друг сел на него первым",
	},
	# Said to a guest who tries to sell a machine in somebody else's valley.
	"say_sell_at_home": {
		EN: "sell it in your own valley",
		FR: "vends-le dans ta propre vallée",
		RU: "продай его в своей долине",
	},
	# Said to a guest who tries to buy a machine in somebody else's valley.
	"say_buy_at_home": {
		EN: "buy it in your own valley",
		FR: "achète-le dans ta propre vallée",
		RU: "купи его в своей долине",
	},
	# Said when every one of the machine is being ridden, so none can be taken.
	"say_machine_in_use": {
		EN: "somebody is riding it — sell it when they get off",
		FR: "quelqu'un le monte — vends-le quand il sera descendu",
		RU: "на нём сейчас едут — продай, когда слезут",
	},
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
	"shop_chocolate": {EN: "chocolate", FR: "chocolat", RU: "шоколадка"},
	"shop_chocolate_what": {
		EN: "one coin a bar, eat it anywhere",
		FR: "une pièce, à manger n'importe où",
		RU: "монета за плитку, съешь где угодно",
	},
	"shop_shears": {EN: "shears", FR: "cisailles", RU: "ножницы"},
	"shop_shears_what": {
		EN: "shear the sheep for their wool",
		FR: "tonds les moutons pour leur laine",
		RU: "стриги овец и получай шерсть",
	},
	"shop_saddle": {EN: "saddle", FR: "selle", RU: "седло"},
	"shop_saddle_what": {
		EN: "your horse takes hills it would slide off",
		FR: "ton cheval grimpe où il glissait",
		RU: "конь берёт склоны, с которых съезжал",
	},
	"shop_motorcycle": {EN: "motorcycle", FR: "moto", RU: "мотоцикл"},
	"shop_motorcycle_what": {
		EN: "fastest of all, but the animals run from the noise",
		FR: "le plus rapide, mais le bruit fait fuir les animaux",
		RU: "самый быстрый, но звери разбегаются от шума",
	},
	"shop_quad": {EN: "quad bike", FR: "quad", RU: "квадроцикл"},
	"shop_quad_what": {
		EN: "four wheels: steadier than the motorcycle, and climbs nearly as well",
		FR: "quatre roues : plus stable que la moto, et grimpe presque aussi bien",
		RU: "четыре колеса: устойчивее мотоцикла и лезет почти так же",
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
	"why_reserved": {EN: "not here", FR: "pas ici", RU: "не здесь"},
	# The whole roof, aimed where there is no room to cover.
	"why_no_walls": {
		EN: "put walls all the way round first",
		FR: "mets d'abord des murs tout autour",
		RU: "сначала поставь стены вокруг",
	},
	"why_not_box": {
		EN: "the room needs four straight sides",
		FR: "la pièce doit avoir quatre côtés droits",
		RU: "у комнаты должно быть четыре ровные стороны",
	},
	# A whole roof over walls that are not all as tall as each other.
	"why_uneven": {
		EN: "the walls are not all as tall",
		FR: "les murs n'ont pas tous la même hauteur",
		RU: "стены разной высоты",
	},
	# A trunk where the building would stand.
	"why_tree": {
		EN: "a tree is in the way", FR: "un arbre gêne", RU: "тут растёт дерево",
	},
	# Somebody, something with legs or a parked machine where the piece would go up.
	"why_someone": {
		EN: "someone is standing there", FR: "quelqu'un est là", RU: "там кто-то стоит",
	},
	# What a ready-made plan still lacks; %s is the list of materials.
	# FR and RU follow with a name and a number ("палка ×23"), not a counted noun,
	# so the colon is what makes it a list and not a broken sentence.
	"why_missing": {EN: "still need %s", FR: "il manque : %s", RU: "ещё нужно: %s"},
	# A stack of walls already as tall as a house may be.
	"why_too_high": {EN: "as high as it goes", FR: "on ne peut pas plus haut", RU: "выше нельзя"},
	# A piece laid a storey up with nothing under it to stand on.
	"why_nothing_below": {EN: "nothing under it", FR: "rien dessous", RU: "под ним пусто"},
	# The pool's turnstile.
	"say_ticket": {EN: "pool: %d{coin|coins} to go in", FR: "piscine : %d{pièce|pièces} pour entrer", RU: "бассейн: вход %d{монета|монеты|монет}"},
	"ask_buy_ride": {
		EN: "buy a ride for %d{coin|coins}?", FR: "acheter un tour pour %d{pièce|pièces} ?",
		RU: "купить поездку за %d{монету|монеты|монет}?"
	},
	"ask_use_ticket": {
		EN: "use a ticket for this ride?", FR: "utiliser un billet pour ce manège ?",
		RU: "потратить билет на этот аттракцион?"
	},
	"say_park_ticket": {
		EN: "rides: %d{coin|coins} each", FR: "manèges : %d{pièce|pièces} le tour",
		RU: "аттракционы: %d{монета|монеты|монет} за поездку"
	},
	"say_park_bought": {
		EN: "ticket bought — you have %d", FR: "billet acheté — tu en as %d",
		RU: "билет куплен — у тебя их %d"
	},
	"say_wheel_called": {
		EN: "a gondola is coming round to you",
		FR: "une nacelle arrive vers toi",
		RU: "кабинка подъезжает к тебе"
	},
	"say_wheel_here": {
		EN: "in you get — it waits ten seconds",
		FR: "monte — elle attend dix secondes",
		RU: "заходи — ждёт десять секунд"
	},
	"say_wheel_done": {
		EN: "that's your turn — out you get",
		FR: "voilà ton tour — descends",
		RU: "круг окончен — выходи"
	},
	"say_coaster_booked": {
		EN: "the train will pull up for you",
		FR: "le train va s'arrêter pour toi",
		RU: "поезд остановится для тебя"
	},
	# The train has pulled up for a paid ticket, and when its lap is done.
	"say_coaster_here": {
		EN: "the train is here — hop in, it waits ten seconds",
		FR: "le train est là — monte, il attend dix secondes",
		RU: "поезд приехал — садись, он ждёт десять секунд"
	},
	"say_coaster_done": {
		EN: "that's your ride — out you get, or press the button for another",
		FR: "voilà ton tour — descends, ou appuie sur le bouton pour un autre",
		RU: "поездка окончена — выходи или нажми кнопку, чтобы ещё раз"
	},
	# A ticket is paid and the child is not in a seat, or the carousel is going
	# round for somebody else: said again every few seconds, because a ride that
	# does not start and does not say why is a ride that looks broken.
	"say_take_a_seat": {
		EN: "sit on a seat — the bars come down for you", FR: "assieds-toi sur un siège — la barre va descendre",
		RU: "сядь на сиденье — опустится дуга"
	},
	"say_friend_deciding": {
		EN: "your friend has not said yes yet — the ride waits",
		FR: "ton ami n'a pas encore dit oui — le manège attend",
		RU: "друг ещё не ответил — аттракцион ждёт"
	},
	"say_carousel_busy": {
		EN: "the carousel is busy — wait, it will be yours", FR: "le manège tourne — attends, ce sera ton tour",
		RU: "карусель занята — подожди, скоро твоя очередь"
	},
	"say_park_put_off": {
		EN: "no ticket, no ride — off you get",
		FR: "pas de billet, pas de tour — descends",
		RU: "без билета кататься нельзя — выходим"
	},
	"say_park_used_ticket": {
		EN: "enjoy the ride — tickets left: %d", FR: "bon voyage — billets restants : %d",
		RU: "приятной поездки — билетов осталось: %d"
	},
	"say_welcome_pool": {EN: "in you go — have a swim!", FR: "entre — bonne baignade !", RU: "проходи — поплавай!"},
	# %s is the list of missing materials.
	"why_need": {EN: "need %s", FR: "il faut : %s", RU: "нужно: %s"},

	# Which storey the ghost is on. %d counts from 1 for the ground floor,
	# because "floor 0" means nothing to a child.
	"ui_ground_floor": {EN: "ground floor", FR: "rez-de-chaussée", RU: "первый этаж"},
	"ui_upper_floor": {EN: "floor %d", FR: "niveau %d", RU: "этаж %d"},

	# Aiming a kick.
	"aim_slide": {EN: "slide to aim", FR: "glisse pour viser", RU: "води пальцем — целься"},
	"aim_ground": {EN: "along the ground", FR: "au ras du sol", RU: "низом"},
	"aim_over": {EN: "up and over", FR: "en cloche", RU: "повыше"},
	"aim_high": {EN: "high over the top", FR: "très haut", RU: "высоко навесом"},

	# The scoreboard by the pitch: its thin title, and what is said when a child
	# starts the game again from it.
	"board_title": {EN: "GOALS", FR: "BUTS", RU: "ГОЛЫ"},
	"say_new_game": {EN: "new game: 0 – 0", FR: "nouveau match : 0 – 0", RU: "новая игра: 0 – 0"},
	# A match is first to five. The board says it in a few words, the screen in a
	# sentence, and the chip tells each of two children which side they are.
	"board_wins_blue": {EN: "BLUE WINS", FR: "BLEU GAGNE", RU: "СИНИЕ ПОБЕДИЛИ"},
	"board_wins_red": {EN: "RED WINS", FR: "ROUGE GAGNE", RU: "КРАСНЫЕ ПОБЕДИЛИ"},
	"say_won_blue": {EN: "BLUE WINS THE MATCH!", FR: "LE BLEU GAGNE LE MATCH !", RU: "СИНИЕ ВЫИГРАЛИ МАТЧ!"},
	"say_won_red": {EN: "RED WINS THE MATCH!", FR: "LE ROUGE GAGNE LE MATCH !", RU: "КРАСНЫЕ ВЫИГРАЛИ МАТЧ!"},
	"you_blue": {EN: "you: blue", FR: "toi : bleu", RU: "ты: синие"},
	"you_red": {EN: "you: red", FR: "toi : rouge", RU: "ты: красные"},

	# Things the world says back.
	"say_goal": {EN: "GOAL", FR: "BUT", RU: "ГОЛ"},
	# %d is the wood taken, %d the coins the tree's growing had paid.
	"say_felled_own": {
		EN: "your own tree: +%d wood, but −%d: the coins it grew for",
		FR: "ton propre arbre : +%d bois, mais −%d : les pièces de sa pousse",
		RU: "своё дерево: древесина +%d, но −%d: монеты за его рост",
	},
	# %d is the coins the tree's growing had paid, taken back as the axe does.
	"say_took_tree": {
		EN: "tree taken down: −%d, the coins it grew for",
		FR: "arbre retiré : −%d, les pièces de sa pousse",
		RU: "дерево убрано: −%d — монеты, которые оно принесло",
	},
	"say_grown": {EN: "your tree has grown", FR: "ton arbre a poussé", RU: "твоё дерево выросло"},
	"say_grove": {
		EN: "a grove — and the birds have found it",
		FR: "un bosquet — les oiseaux l'ont trouvé",
		RU: "роща — и птицы её нашли",
	},
	# %d is how many rocks have been cleared in total.
	"say_cleared": {EN: "cleared it — %d", FR: "franchi — %d", RU: "перепрыгнуто — %d"},
	"say_not_here": {EN: "not here", FR: "pas ici", RU: "не сюда"},
	"say_nothing_here": {
		EN: "nothing to take down here",
		FR: "rien à démonter ici",
		RU: "тут нечего разбирать",
	},
	"say_nothing_to_undo": {EN: "nothing to undo", FR: "rien à annuler", RU: "нечего отменять"},
	# A piece taken down with what stood on it: the wall under a wall, the walls
	# under a roof, the floor under a bed.
	"say_took_stack": {
		EN: "took it down with what stood on it",
		FR: "démonté avec ce qui était dessus",
		RU: "разобрано вместе с тем, что стояло сверху",
	},
	# Stairs and a floor over them, which a child would walk into.
	"why_headroom": {
		EN: "stairs need room above", FR: "l'escalier a besoin de place au-dessus",
		RU: "над лестницей нужно место",
	},
	# The free meal at a child's own cafe comes once in a while; %d is how many
	# minutes until the next, and a coin buys one now.
	"say_free_wait": {
		EN: "next free meal in %d min — or pay a coin",
		FR: "prochain repas gratuit dans %d min — ou paie une pièce",
		RU: "бесплатный обед через %d мин — или за монетку",
	},
	# The one line shown to a child who has not yet built a house, for the step
	# after the ones that stand: walls, then a floor, then a roof, then a bed.
	"hint_build_walls": {
		EN: "Start with walls: pick one, then tap +",
		FR: "Commence par des murs : choisis-en un, puis appuie sur +",
		RU: "Сначала стены: выбери стену и нажми +",
	},
	"hint_build_floor": {
		EN: "Now a floor to stand on", FR: "Maintenant un sol pour marcher",
		RU: "Теперь пол, чтобы по нему ходить",
	},
	"hint_build_roof": {
		EN: "Now a roof: pick whole roof", FR: "Maintenant un toit : choisis toit entier",
		RU: "Теперь крыша: выбери «вся крыша»",
	},
	"hint_build_bed": {
		EN: "Last, a bed to sleep in", FR: "Enfin, un lit pour dormir",
		RU: "И в конце кровать, чтобы спать",
	},
	# %s is the name of the piece.
	# The map: what its pictures are called, and what is said when a child
	# chooses a place to go to.
	"map_legend": {EN: "What is on the map", FR: "Sur la carte", RU: "Что на карте"},
	"map_home": {EN: "home", FR: "maison", RU: "дом"},
	"map_pitch": {EN: "football", FR: "football", RU: "футбол"},
	"map_range": {EN: "archery", FR: "tir à l'arc", RU: "стрельба"},
	"map_fairground": {EN: "fairground", FR: "fête foraine", RU: "аттракционы"},
	"map_bridge": {EN: "bridge", FR: "pont", RU: "мост"},
	"map_lake": {EN: "lake", FR: "lac", RU: "озеро"},
	"map_boats": {EN: "boats", FR: "bateaux", RU: "лодки"},
	"map_horse": {EN: "horse", FR: "cheval", RU: "конь"},
	"map_friend": {EN: "friend", FR: "ami", RU: "друг"},
	"map_mountain": {EN: "big mountain", FR: "la montagne", RU: "большая гора"},
	"map_you": {EN: "you", FR: "toi", RU: "ты"},
	"map_built": {EN: "your buildings", FR: "tes maisons", RU: "постройки"},
	"map_planted": {EN: "your trees", FR: "tes arbres", RU: "твои деревья"},
	# %d is metres.
	"map_metres": {EN: "%d m", FR: "%d m", RU: "%d м"},
	# %s is the name of a place on the map.
	"say_map_going": {EN: "Let's go: %s", FR: "On y va : %s", RU: "Идём: %s"},
	"say_map_arrived": {EN: "Here it is: %s!", FR: "Voilà : %s !", RU: "Пришли: %s!"},
	"say_map_far": {EN: "%s is far, far away", FR: "%s est très, très loin", RU: "%s очень далеко"},
	"say_took_back": {EN: "took the %s back", FR: "tu as repris : %s", RU: "разобрано: %s"},
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
	# Circassian falls back to Russian and everything else to English: see the
	# note on AD. `entry.get(RU, entry[EN])` rather than entry[RU] because the
	# fallback must not itself be able to fail.
	if _language == AD and not entry.has(AD):
		return entry.get(RU, entry[EN])
	return entry.get(_language, entry[EN])

## The same, with arguments — so a caller never has to remember which strings
## take a value and format them by hand in two places.
##
## A number that sits beside a noun can carry its plural right after the
## placeholder: "%d{coin|coins}" reads "1 coin" and "2 coins", and a Russian
## text gives three forms, "%d{монета|монеты|монет}". That keeps the agreement
## in the one file a parent opens to fix a clumsy phrase, and out of the
## callers, which just pass the number. A text that would rather dodge the
## question still can, with the "noun: %d" shape the Russian already uses.
static func format(key: String, values: Array) -> String:
	return _with_plurals(Text.of(key), values) % values

## Rewrites each "%d{one|many}" as "%d" plus the right word for that number,
## leaving every other placeholder, and "%%", exactly as they were. The number
## each group belongs to is the one its placeholder will be given, found by
## counting placeholders from the left.
static func _with_plurals(template: String, values: Array) -> String:
	if not template.contains("{"):
		return template
	var out := ""
	var arg := 0
	var at := 0
	while at < template.length():
		var c := template[at]
		if c != "%" or at + 1 >= template.length():
			out += c
			at += 1
			continue
		var spec := template.substr(at, 2)
		out += spec
		at += 2
		if spec == "%%":
			continue
		if spec == "%d" and at < template.length() and template[at] == "{":
			var close := template.find("}", at)
			if close > at and arg < values.size() and typeof(values[arg]) in [TYPE_INT, TYPE_FLOAT]:
				var forms := template.substr(at + 1, close - at - 1).split("|")
				out += " " + forms[_plural_form(forms.size(), int(values[arg]))]
				at = close + 1
		arg += 1
	return out

## Which of a group's forms a number takes. Three forms are Russian's: 1, 21
## and 101 take the first, 2 to 4 (but not 12 to 14) the second, the rest the
## third. Two forms are English's, except in French, where nought is singular
## too ("0 pièce").
static func _plural_form(forms: int, count: int) -> int:
	var n := absi(count)
	if forms >= 3:
		var last := n % 10
		var last_two := n % 100
		if last == 1 and last_two != 11:
			return 0
		if last >= 2 and last <= 4 and (last_two < 12 or last_two > 14):
			return 1
		return 2
	if _language == FR:
		return 0 if n < 2 else 1
	return 0 if n == 1 else 1
