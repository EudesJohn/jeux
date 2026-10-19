extends Resource
class_name AffixData
## Les 10 affixes d'arme de l'ANNEXE §3.3. Aucune logique de combat ici : le
## tirage et l'agrégation des bonus sont des fonctions pures, testables.

const POOL := {
	"tranchant": {"label": "Tranchant", "damage": 0.10},
	"critique": {"label": "Critique", "crit": 0.08},
	"saignement": {"label": "Saignement", "dot": 3.0, "duration": 4.0},
	"vampirique": {"label": "Vampirique", "lifesteal": 0.03},
	"rapide": {"label": "Rapide", "speed": 0.10},
	"brulant": {"label": "Brûlant", "burn": 0.0, "duration": 3.0},
	"etourdissant": {"label": "Étourdissant", "stun": 0.08},
	"energique": {"label": "Énergique", "energy": 0.20},
	"chanceux": {"label": "Chanceux", "cauris": 0.15},
	"brise_garde": {"label": "Brise-garde", "guard_break": 0.25},
}

## Ordre stable du catalogue (les .tres et les tests s'y réfèrent).
const IDS: Array[String] = [
	"tranchant", "critique", "saignement", "vampirique", "rapide",
	"brulant", "etourdissant", "energique", "chanceux", "brise_garde",
]


static func label(id: String) -> String:
	var info: Dictionary = POOL.get(id, {})
	return str(info.get("label", id))


static func is_known(id: String) -> bool:
	return POOL.has(id)


## Tire `count` affixes distincts parmi `allowed` (ou tout le catalogue si la
## liste est vide, comme pour une arme sans restriction).
## Le générateur est passé explicitement : les tests sont reproductibles.
static func roll(count: int, rng: RandomNumberGenerator, allowed: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for id in (allowed if not allowed.is_empty() else IDS):
		if is_known(id) and not pool.has(id):
			pool.append(id)
	var picked: Array[String] = []
	var wanted := clampi(count, 0, pool.size())
	for _i in wanted:
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


## Somme des bonus de dégâts additifs (tranchant, etc.) d'une liste d'affixes.
static func damage_bonus(affixes: Array[String]) -> float:
	var total := 0.0
	for id in affixes:
		total += float(POOL.get(id, {}).get("damage", 0.0))
	return total


## Somme d'une statistique précise (crit, speed, cauris…) sur une liste.
static func stat_bonus(affixes: Array[String], stat: String) -> float:
	var total := 0.0
	for id in affixes:
		total += float(POOL.get(id, {}).get(stat, 0.0))
	return total
