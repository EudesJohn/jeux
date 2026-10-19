extends RefCounted
class_name GearData
## Sets d'armure et talismans (ANNEXE §4.5 et §4.6). Données pures : le HUD,
## l'inventaire et les statistiques de la joueuse lisent les mêmes tables.
##
## Les bonus de set s'activent par nombre de pièces (2 ou 4) ; les talismans
## s'additionnent (3 emplacements). Les clés de statistiques sont celles que
## consomme le gameplay :
##   health_mult, damage_reduction, potion_bonus, energy_bonus, speed_mult,
##   stability, loot_mult, full_health_damage, perfect_guard_window, revive.

const SETS := {
	"recrue": {
		"name": "Recrue d'Abomey",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"health_mult": 0.10},
		"bonus_4": {"potion_bonus": 1},
		"desc_2": "+10 % de vie", "desc_4": "+1 potion maximale",
	},
	"gardienne": {
		"name": "Gardienne du palais",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"damage_reduction": 0.10},
		"bonus_4": {"perfect_guard_energy": 20.0},
		"desc_2": "−10 % de dégâts reçus", "desc_4": "Garde parfaite : +20 énergie",
	},
	"chasseuse": {
		"name": "Chasseuse du fleuve",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"speed_mult": 0.10},
		"bonus_4": {"perfect_dodge_arrow": 1},
		"desc_2": "+10 % de vitesse", "desc_4": "Esquive parfaite : flèche automatique",
	},
	"forgeronne": {
		"name": "Forgeronne",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"stability": 15.0},
		"bonus_4": {"heavy_stun": 1},
		"desc_2": "+15 de stabilité", "desc_4": "Les coups lourds étourdissent",
	},
	"pretresse": {
		"name": "Prêtresse vodoun",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"energy_bonus": 15.0},
		"bonus_4": {"special_refund": 0.30},
		"desc_2": "+15 énergie maximale", "desc_4": "Le spécial rembourse 30 %",
	},
	"legende": {
		"name": "Légende d'Abomey",
		"pieces": ["tete", "torse", "jambes", "bracelets"],
		"bonus_2": {"all_attributes": 10},
		"bonus_4": {"revive": 1},
		"desc_2": "+10 % à tous les attributs", "desc_4": "Résurrection une fois par niveau",
	},
}

const TALISMANS := {
	"cauri": {"name": "Cauri porte-bonheur", "bonus": {"loot_mult": 0.20}},
	"dent_du_lion": {"name": "Dent du lion", "bonus": {"full_health_damage": 0.15}},
	"plume": {"name": "Plume du messager", "bonus": {"speed_mult": 0.10}},
	"oeil": {"name": "Œil des ancêtres", "bonus": {"perfect_guard_window": 0.05}},
}

const SET_IDS: Array[String] = ["recrue", "gardienne", "chasseuse",
	"forgeronne", "pretresse", "legende"]
const TALISMAN_IDS: Array[String] = ["cauri", "dent_du_lion", "plume", "oeil"]
const MAX_TALISMANS: int = 3


static func set_name(id: String) -> String:
	return str(SETS.get(id, {}).get("name", id))


static func talisman_name(id: String) -> String:
	return str(TALISMANS.get(id, {}).get("name", id))


## Bonus d'un set pour `pieces` pièces portées (0 à 4).
static func set_bonus(set_id: String, pieces: int) -> Dictionary:
	if not SETS.has(set_id):
		return {}
	var out: Dictionary = {}
	if pieces >= 2:
		_merge(out, SETS[set_id]["bonus_2"])
	if pieces >= 4:
		_merge(out, SETS[set_id]["bonus_4"])
	return out


## Additionne les bonus de plusieurs talismans (3 maximum).
static func talisman_bonus(ids: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for index in mini(ids.size(), MAX_TALISMANS):
		var id := ids[index]
		if TALISMANS.has(id):
			_merge(out, TALISMANS[id]["bonus"])
	return out


## Ensemble des bonus actifs : set + talismans.
static func aggregate(set_id: String, pieces: int,
		talismans: Array[String] = []) -> Dictionary:
	var out := set_bonus(set_id, pieces)
	_merge(out, talisman_bonus(talismans))
	return out


static func _merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		target[key] = float(target.get(key, 0.0)) + float(source[key])
