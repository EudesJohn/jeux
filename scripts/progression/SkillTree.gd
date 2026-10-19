extends RefCounted
class_name SkillTree
## Arbre de compétences (ANNEXE §4.4). Version de départ : **15 talents**,
## 5 par branche. Les effets sont des statistiques additives ; le gameplay les
## lit par `stat_total()`. Les talents marqués `unlock` débloquent une capacité
## (combo de 4, second spécial, ralenti) : `has_unlock()` les interroge.

const BRANCHES: Array[String] = ["attaque", "defense", "esprit"]
const BRANCH_LABELS := {
	"attaque": "Attaque", "defense": "Défense", "esprit": "Esprit",
}
const MAX_RANK: int = 3

## `costs` : coût en points de compétence pour chaque rang (1 à 3).
const SKILLS := {
	# --- Attaque -------------------------------------------------
	"frappe_lourde": {
		"branch": "attaque", "name": "Frappe lourde", "costs": [1, 2, 3],
		"stat": "heavy_damage", "per_rank": 0.05,
		"desc": "+5 % de dégâts sur les coups lourds par rang",
	},
	"oeil_du_faucon": {
		"branch": "attaque", "name": "Œil du faucon", "costs": [1, 2, 3],
		"stat": "crit", "per_rank": 0.03,
		"desc": "+3 % de chance de critique par rang",
	},
	"execution": {
		"branch": "attaque", "name": "Exécution", "costs": [1, 2, 3],
		"stat": "execute_damage", "per_rank": 0.10,
		"desc": "+10 % de dégâts sur un ennemi sous 25 % de vie",
	},
	"brise_garde": {
		"branch": "attaque", "name": "Brise-garde", "costs": [1, 2, 3],
		"stat": "guard_break", "per_rank": 0.08,
		"desc": "+8 % de vitesse pour briser une garde",
	},
	"combo_quatre": {
		"branch": "attaque", "name": "Enchaînement de quatre", "costs": [1, 0, 0],
		"stat": "", "per_rank": 0.0, "unlock": "combo_4",
		"desc": "Débloque le quatrième coup du combo",
	},
	# --- Défense -------------------------------------------------
	"garde_parfaite": {
		"branch": "defense", "name": "Garde parfaite", "costs": [1, 2, 3],
		"stat": "perfect_guard_window", "per_rank": 0.02,
		"desc": "+0,02 s de fenêtre de garde parfaite par rang",
	},
	"esquive_enchaine": {
		"branch": "defense", "name": "Esquive enchaînée", "costs": [1, 2, 3],
		"stat": "dodge_cooldown", "per_rank": -0.08,
		"desc": "−8 % de temps de recharge d'esquive par rang",
	},
	"regeneration": {
		"branch": "defense", "name": "Régénération", "costs": [1, 2, 3],
		"stat": "regen", "per_rank": 2.0,
		"desc": "+2 vie par seconde hors combat par rang",
	},
	"peau_dure": {
		"branch": "defense", "name": "Peau dure", "costs": [1, 2, 3],
		"stat": "damage_reduction", "per_rank": 0.04,
		"desc": "−4 % de dégâts reçus par rang",
	},
	"contre": {
		"branch": "defense", "name": "Contre", "costs": [1, 2, 3],
		"stat": "counter_damage", "per_rank": 0.10,
		"desc": "+10 % de dégâts de contre-attaque par rang",
	},
	# --- Esprit --------------------------------------------------
	"energie": {
		"branch": "esprit", "name": "Souffle profond", "costs": [1, 2, 3],
		"stat": "energy_max", "per_rank": 10.0,
		"desc": "+10 énergie maximale par rang",
	},
	"special_moins_cher": {
		"branch": "esprit", "name": "Spécial économe", "costs": [1, 2, 3],
		"stat": "special_cost", "per_rank": -0.08,
		"desc": "−8 % de coût du spécial par rang",
	},
	"second_special": {
		"branch": "esprit", "name": "Deuxième spécial", "costs": [2, 0, 0],
		"stat": "", "per_rank": 0.0, "unlock": "second_special",
		"desc": "Débloque un second spécial équipable",
	},
	"esprits": {
		"branch": "esprit", "name": "Voix des esprits", "costs": [1, 2, 3],
		"stat": "spirit_damage", "per_rank": 0.15,
		"desc": "+15 % de dégâts des esprits par rang",
	},
	"ralenti": {
		"branch": "esprit", "name": "Temps suspendu", "costs": [2, 0, 0],
		"stat": "", "per_rank": 0.0, "unlock": "slow_time",
		"desc": "Débloque le ralenti du temps",
	},
}


static func is_known(id: String) -> bool:
	return SKILLS.has(id)


static func branch_of(id: String) -> String:
	return str(SKILLS.get(id, {}).get("branch", ""))


static func label(id: String) -> String:
	return str(SKILLS.get(id, {}).get("name", id))


## Les coûts à 0 terminent la liste : ils ne sont pas des rangs gratuits.
static func max_rank(id: String) -> int:
	var costs: Array = SKILLS.get(id, {}).get("costs", [])
	var count := 0
	for price in costs:
		if int(price) <= 0:
			break
		count += 1
	return count


## Coût du prochain rang, ou -1 si le rang maximum est atteint.
static func cost(id: String, current_rank: int) -> int:
	if not is_known(id) or current_rank < 0 or current_rank >= max_rank(id):
		return -1
	var price := int((SKILLS[id]["costs"] as Array)[current_rank])
	return price if price > 0 else -1


static func cost_list(id: String) -> Array:
	return (SKILLS.get(id, {}).get("costs", []) as Array).duplicate()


static func branch_skills(branch: String) -> Array[String]:
	var out: Array[String] = []
	for id in SKILLS:
		if branch_of(id) == branch:
			out.append(id)
	return out


## Un talent est apprenable s'il reste des points et si le prérequis de rang
## est respecté (les rangs coûteux restent dans l'ordre).
static func can_learn(id: String, current_rank: int, points: int) -> bool:
	var price := cost(id, current_rank)
	return price >= 0 and points >= price


## Somme d'une statistique sur tous les talents appris.
static func stat_total(ranks: Dictionary, stat: String) -> float:
	var total := 0.0
	for id in ranks:
		var info: Dictionary = SKILLS.get(id, {})
		if str(info.get("stat", "")) != stat:
			continue
		total += float(info.get("per_rank", 0.0)) * float(int(ranks[id]))
	return total


## Capacité débloquée (combo_4, second_special, slow_time).
static func has_unlock(ranks: Dictionary, unlock: String) -> bool:
	for id in ranks:
		if int(ranks[id]) <= 0:
			continue
		if str(SKILLS.get(id, {}).get("unlock", "")) == unlock:
			return true
	return false


static func total_spent(ranks: Dictionary) -> int:
	var total := 0
	for id in ranks:
		var rank := clampi(int(ranks[id]), 0, max_rank(id))
		var costs: Array = SKILLS.get(id, {}).get("costs", [])
		for index in rank:
			total += int(costs[index])
	return total
