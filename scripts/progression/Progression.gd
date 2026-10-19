extends RefCounted
class_name Progression
## Progression de la guerrière (ANNEXE §4) : niveaux 1 à 60, attributs,
## formules de vie, de dégâts et de critique. Tout est ici, en fonctions pures,
## pour que l'interface et les tests lisent les mêmes nombres.

const MAX_LEVEL: int = 60
const POINTS_PER_LEVEL: int = 3
## 1 point de compétence tous les 2 niveaux (§4.1).
const SKILL_POINT_EVERY: int = 2
const ATTRIBUTES: Array[String] = ["force", "agilite", "vitalite", "esprit", "chance"]
const ATTRIBUTE_LABELS := {
	"force": "Force", "agilite": "Agilité", "vitalite": "Vitalité",
	"esprit": "Esprit", "chance": "Chance",
}

## XP nécessaire pour passer du niveau `level` au suivant : 100 × niveau^1,6.
## 0 au niveau maximum.
static func xp_to_next(level: int) -> int:
	if level < 1 or level >= MAX_LEVEL:
		return 0
	return int(round(100.0 * pow(float(level), 1.6)))


## XP cumulée pour atteindre `level` depuis le niveau 1.
static func total_xp_for(level: int) -> int:
	var total := 0
	for current in range(1, clampi(level, 1, MAX_LEVEL)):
		total += xp_to_next(current)
	return total


## Niveau atteint avec cette XP cumulée (borné à 60).
static func level_for_xp(xp: int) -> int:
	var level := 1
	var remaining := maxi(xp, 0)
	while level < MAX_LEVEL:
		var needed := xp_to_next(level)
		if remaining < needed:
			break
		remaining -= needed
		level += 1
	return level


## Points d'attributs gagnés depuis le niveau 1 (3 par niveau, §4.1).
static func attribute_points_for(level: int) -> int:
	return POINTS_PER_LEVEL * (clampi(level, 1, MAX_LEVEL) - 1)


## Points de compétence : 1 tous les 2 niveaux.
static func skill_points_for(level: int) -> int:
	return floori(float(clampi(level, 1, MAX_LEVEL) - 1) / float(SKILL_POINT_EVERY))


## Vie maximale : 100 + 8 × Vitalité + 4 × niveau (§4.2).
static func max_health(vitalite: int, level: int) -> float:
	return 100.0 + 8.0 * float(maxi(vitalite, 0)) + 4.0 * float(clampi(level, 1, MAX_LEVEL))


## Dégâts d'un coup (§4.3). `bonus` = affixes + runes + talismans (additif).
static func melee_damage(base_weapon: float, force: int, rarity_mult: float,
		upgrade_level: int, bonus: float = 0.0, is_crit: bool = false) -> float:
	var damage := base_weapon \
		* (1.0 + 0.03 * float(maxi(force, 0))) \
		* maxf(rarity_mult, 0.01) \
		* (1.0 + 0.08 * float(clampi(upgrade_level, 0, 10))) \
		* (1.0 + bonus)
	if is_crit:
		damage *= 1.5
	return damage


## Chance de critique : 8 % de base + 0,5 % par Agilité + 0,4 % par Chance.
static func crit_chance(agilite: int, chance: int) -> float:
	return clampf(0.08 + 0.005 * float(maxi(agilite, 0)) + 0.004 * float(maxi(chance, 0)), 0.0, 1.0)


## Dégâts par seconde estimés (fiche de personnage, §6).
static func estimated_dps(base_weapon: float, attack_speed: float, force: int,
		rarity_mult: float, upgrade_level: int, bonus: float,
		agilite: int, chance: int) -> float:
	var damage := melee_damage(base_weapon, force, rarity_mult, upgrade_level, bonus)
	var crit := crit_chance(agilite, chance)
	return damage * (1.0 + crit * 0.5) * maxf(attack_speed, 0.01)


## Bonus de dégâts de la Force seul (pour l'affichage « +x % »).
static func force_mult(force: int) -> float:
	return 1.0 + 0.03 * float(maxi(force, 0))


## Vitesse d'attaque et de déplacement : +1,5 % par Agilité (§4.2).
static func agility_mult(agilite: int) -> float:
	return 1.0 + 0.015 * float(maxi(agilite, 0))


## Énergie maximale : 100 + 4 par Esprit ; gain +2 % par Esprit (§4.2).
static func max_energy(esprit: int) -> float:
	return 100.0 + 4.0 * float(maxi(esprit, 0))


## Gain de cauris : +1 % par Chance (§4.2).
static func cauris_mult(chance: int) -> float:
	return 1.0 + 0.01 * float(maxi(chance, 0))
