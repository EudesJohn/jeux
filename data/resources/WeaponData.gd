extends Resource
class_name WeaponData
## Fiche d'une arme (ANNEXE §3 et §8). Une ressource = une arme : les valeurs
## ne sont jamais écrites en dur dans le code de combat.
##
## `damage_at()` est la seule formule de dégâts d'arme du projet : la rareté,
## le niveau d'amélioration et les bonus (affixes, runes, talismans) entrent
## ici. Les attributs de la guerrière sont appliqués par `Progression`.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }
enum Kind { BLADE, DUAL, POLEARM, BLUNT, RANGED, SHORT }

## Multiplicateur de dégâts par rareté (§3.1) : commune -> mythique.
const RARITY_MULT: Array[float] = [1.0, 1.15, 1.35, 1.6, 2.0]
const RARITY_NAMES: Array[String] = ["Commune", "Rare", "Épique", "Légendaire", "Mythique"]
const RARITY_COLORS: Array[Color] = [
	Color(0.62, 0.62, 0.62), Color(0.25, 0.55, 0.95),
	Color(0.62, 0.30, 0.85), Color(0.90, 0.72, 0.20),
	Color(0.85, 0.18, 0.15),
]
## Nombre d'affixes tirés à l'obtention (§3.1).
const AFFIX_COUNT: Array[int] = [0, 1, 2, 3, 3]

@export var id: String = "sabre"
@export var display_name: String = "Sabre gubasa"
@export var display_key: String = "WEAPON_SABRE"
@export var kind: Kind = Kind.BLADE
@export var rarity: Rarity = Rarity.COMMON
@export var base_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var reach: float = 1.6
@export var is_ranged: bool = false
@export var rune_slots: int = 0
@export var possible_affixes: Array[String] = []
@export var special_scene: PackedScene
@export var mesh_scene: PackedScene
@export var combo_extensions: Array[String] = []
@export var price: int = 0


func rarity_mult() -> float:
	return RARITY_MULT[clampi(int(rarity), 0, RARITY_MULT.size() - 1)]


func rarity_name() -> String:
	return RARITY_NAMES[clampi(int(rarity), 0, RARITY_NAMES.size() - 1)]


func rarity_color() -> Color:
	return RARITY_COLORS[clampi(int(rarity), 0, RARITY_COLORS.size() - 1)]


## Affixes tirés à l'obtention, selon la rareté (§3.1).
func affix_count() -> int:
	return AFFIX_COUNT[clampi(int(rarity), 0, AFFIX_COUNT.size() - 1)]


## Dégâts d'un coup à ce niveau d'amélioration.
## `bonus` regroupe les pourcentages additifs (affixes + runes + talismans).
func damage_at(level: int, bonus: float = 0.0) -> float:
	var upgrades := clampi(level, 0, 10)
	return base_damage * rarity_mult() * (1.0 + 0.08 * float(upgrades)) * (1.0 + bonus)


## Dégâts par seconde théoriques (indicateur de fiche, §6).
func dps_at(level: int, bonus: float = 0.0) -> float:
	return damage_at(level, bonus) * maxf(attack_speed, 0.01)
