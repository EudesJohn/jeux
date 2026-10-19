extends RefCounted
class_name EliteAffix
## Affixes des ennemis élites (ANNEXE §7.3). Un ennemi normal n'en a aucun ;
## un ennemi créé sous un palier de difficulté peut en recevoir 1 ou 2 selon
## `DifficultyTier.max_elite_affixes` (0 en Récit/Guerrière, 1 en Légende,
## 2 en Éternelle).
##
## Les effets sont des fonctions pures : `EnemyBase3D` les interroge à chaque
## coup, déplacement ou mort, ce qui rend le comportement testable sans scène.

const POOL := {
	"blinde": {"label": "Blindé", "damage_taken": 0.6},
	"enrage": {"label": "Enragé", "speed": 1.5, "threshold": 0.5},
	"vampire": {"label": "Vampire", "lifesteal": 0.25},
	"explosif": {"label": "Explosif", "radius": 2.6, "damage": 0.6},
	"rapide": {"label": "Rapide", "speed": 1.4},
	"invocateur": {"label": "Invocateur", "period": 10.0},
	"bouclier": {"label": "Bouclier d'esprit", "charges": 1},
}

const IDS: Array[String] = [
	"blinde", "enrage", "vampire", "explosif", "rapide", "invocateur", "bouclier",
]


static func is_known(id: String) -> bool:
	return POOL.has(id)


static func label(id: String) -> String:
	return str(POOL.get(id, {}).get("label", id))


## Tire `count` affixes distincts (0 = ennemi normal).
static func roll(count: int, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = IDS.duplicate()
	var picked: Array[String] = []
	for _i in clampi(count, 0, pool.size()):
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


## Réduction de dégâts : Blindé divise par 0,6 les coups reçus, sauf étourdi.
static func damage_taken_mult(affixes: Array[String], stunned: bool) -> float:
	if stunned or not affixes.has("blinde"):
		return 1.0
	return float(POOL["blinde"]["damage_taken"])


## Vitesse : Rapide toujours, Enragé sous 50 % de vie (les deux se cumulent).
static func speed_mult(affixes: Array[String], health_ratio: float) -> float:
	var mult := 1.0
	if affixes.has("rapide"):
		mult *= float(POOL["rapide"]["speed"])
	if affixes.has("enrage") and health_ratio < float(POOL["enrage"]["threshold"]):
		mult *= float(POOL["enrage"]["speed"])
	return mult


static func lifesteal(affixes: Array[String]) -> float:
	return float(POOL["vampire"]["lifesteal"]) if affixes.has("vampire") else 0.0


static func explodes(affixes: Array[String]) -> bool:
	return affixes.has("explosif")


static func explosion(affixes: Array[String]) -> Dictionary:
	if not explodes(affixes):
		return {}
	return {"radius": POOL["explosif"]["radius"], "damage": POOL["explosif"]["damage"]}


static func summon_period(affixes: Array[String]) -> float:
	return float(POOL["invocateur"]["period"]) if affixes.has("invocateur") else 0.0


static func shield_charges(affixes: Array[String]) -> int:
	return int(POOL["bouclier"]["charges"]) if affixes.has("bouclier") else 0
