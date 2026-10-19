extends Resource
class_name BossData
## Fiche d'un boss (DESIGN.md § 10). Comme `EnemyData`, tout est dans la
## ressource : `BossBase3D` ne décide rien en dur, il lit cette fiche.
##
## Un boss a **3 phases** (100-60 %, 60-30 %, 30-0 %). Chaque phase accélère le
## télégraphe et ajoute une attaque ; la dernière phase est la plus dangereuse.

const ALL_ATTACKS: Array[String] = [
	"charge",   ## course rectiligne + zone au sol sur la trajectoire
	"sweep",    ## sabre circulaire autour de lui
	"arrows",   ## pluie de flèches : plusieurs cercles rouges au sol
	"slam",     ## frappe au sol : onde circulaire autour de lui
	"orbs",     ## boules d'ombre lancées vers la joueuse
	"teleport", ## disparaît et réapparaît derrière la joueuse
]

@export var id: String = "captain"
@export var display_name: String = "Capitaine des pillards"
@export var chapter: int = 1

## ----------------------------------------------------------------#
## § 10 : vie et dégâts                                           #
## ----------------------------------------------------------------#
@export var health: float = 300.0
@export var damage: float = 14.0
@export var speed: float = 2.4
@export var attack_range: float = 2.6
@export var telegraph_time: float = 0.75
@export var recover_time: float = 0.9
@export var contact_damage: float = 8.0
@export var drops_cauris: int = 60

## ----------------------------------------------------------------#
## Attaques (mélange propre à chaque boss, § 10)                   #
## ----------------------------------------------------------------#
## Attaques disponibles dès la phase 1, puis celles débloquées en phase 2/3.
@export var attacks: Array[String] = ["charge", "sweep"]
@export var phase_2_attacks: Array[String] = []
@export var phase_3_attacks: Array[String] = []
## Distance parcourue par une charge (m) et largeur de la zone (m).
@export var charge_distance: float = 12.0
@export var charge_width: float = 2.2
## Rayon du sabre circulaire et de l'onde de la frappe au sol (m).
@export var sweep_radius: float = 3.6
@export var slam_radius: float = 5.5
## Pluie de flèches : nombre de cercles et rayon de chacun.
@export var arrow_count: int = 4
@export var arrow_radius: float = 1.9
## Combos de la phase 3 (§ 10 « Général rival : combos de 5 coups »).
@export var combo_hits: int = 1
## Phase 2 : appelle des soldats (§ 10 « appelle 2 soldats en phase 2 »).
@export var summon_phase: int = 0
@export var summon_count: int = 0
@export var summon_type: String = "soldier"
## Colosse (§ 10) : l'armure casse après N gardes parfaites.
@export var armor_guards: int = 0
## Sorcier (§ 10) : plonge l'arène dans la nuit.
@export var darken_arena: bool = false

## ----------------------------------------------------------------#
## Rendu graybox (§ 15.3)                                          #
## ----------------------------------------------------------------#
@export var tint: Color = Color(0.62, 0.18, 0.16)
@export var model_scale: float = 1.8


## Attaques connues à une phase donnée (1, 2 ou 3), sans doublon.
func attacks_at_phase(phase: int) -> Array[String]:
	var out: Array[String] = []
	for attack in attacks:
		if ALL_ATTACKS.has(attack) and not out.has(attack):
			out.append(attack)
	if phase >= 2:
		for attack in phase_2_attacks:
			if ALL_ATTACKS.has(attack) and not out.has(attack):
				out.append(attack)
	if phase >= 3:
		for attack in phase_3_attacks:
			if ALL_ATTACKS.has(attack) and not out.has(attack):
				out.append(attack)
	if out.is_empty():
		out.append("sweep")
	return out


## Phase courante (1, 2 ou 3) pour un ratio de vie donné (§ 10).
func phase_for_ratio(ratio: float) -> int:
	if ratio <= 0.3:
		return 3
	if ratio <= 0.6:
		return 2
	return 1


## Le télégraphe raccourcit à chaque phase : plus dur, mais toujours lisible.
func telegraph_for_phase(phase: int) -> float:
	return maxf(0.35, telegraph_time - 0.15 * float(phase - 1))
