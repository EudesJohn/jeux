extends Resource
class_name LevelData
## Fiche d'un niveau (DESIGN.md § 21.1). Le niveau EST ce fichier : changer de
## `.tres` donne un autre niveau, sans une ligne de code (§ 28 PHASE 3 :
## « changer un .tres donne un autre niveau »).

@export var id: String = "level_01"
@export var chapter: int = 1
@export var number: int = 1
@export var display_name: String = "Niveau"

## ----------------------------------------------------------------#
## Forme du niveau (§ 3.1)                                       #
## ----------------------------------------------------------------#
@export_enum("lane", "arena") var layout: String = "lane"
@export var length_m: float = 100.0         ## longueur du couloir (lane)
@export var lane_half_depth: float = 3.0    ## ±3 m jouables en profondeur (§ 3.1)
@export var arena_radius: float = 14.0      ## rayon du disque (arena)

## ----------------------------------------------------------------#
## Objectif (§ 12, § 20.10)                                      #
## ----------------------------------------------------------------#
## PHASE 3 : « clear » (vider les vagues), « survive » (tenir le temps),
## « exit » (atteindre la sortie). PHASE 4 ajoute rescue / escort, PHASE 6 boss.
@export_enum("clear", "survive", "exit", "rescue", "escort", "boss")
var objective: String = "clear"
@export var time_limit: int = 0             ## secondes, 0 = illimité
@export var prisoners: int = 0              ## PHASE 4 : cages à libérer (§ 12.2)
@export var escorts: int = 0                ## PHASE 4 : villageois à escorter (§ 12.2)
## § 12.2 : un villageois a 40 vie ; un prisonnier libéré aussi.
@export var ally_life: float = 40.0
## § 10 : boss de fin de chapitre (objectif « boss »). Vide = aucun gardien.
@export var boss_id: String = ""
## § 12.4 : Chasse aux boss — enchaînement sans pause (le premier est `boss_id`).
@export var boss_chain: Array[String] = []
## § 12.3 : Survie — vagues sans fin, difficulté croissante toutes les 5 vagues.
@export var endless: bool = false

## ----------------------------------------------------------------#
## Contenu                                                       #
## ----------------------------------------------------------------#
@export var enemy_waves: Array[WaveData] = []
## Pièges du § 11 : "pit", "arrows", "fire", "plank", "spikes", "mud".
@export var hazards: Array[String] = []
## Nombre d'exemplaires de chaque piège (placés le long du niveau).
@export var hazards_per_kind: int = 2
## Cauris et potions posés sur le parcours (§ 14.1, § 8.6).
@export var cauri_pickups: int = 6
@export var cauri_per_pickup: int = 3
@export var potion_pickups: int = 1
## Fraction de la longueur où se trouve le checkpoint (§ 13 : « à mi-niveau »).
@export var checkpoint_at: float = 0.5

## ----------------------------------------------------------------#
## Ambiance et récompenses                                       #
## ----------------------------------------------------------------#
@export var night: bool = false             ## § 12.2 : visibilité réduite
@export var modifier: String = ""           ## défi du jour (§ 12.5)
@export var environment_scene: PackedScene  ## décor 3D (graybox si vide)
@export var music_layer_set: String = "palace"
@export var reward_cauris: int = 50
@export var star_time_silver: int = 100
@export var star_time_gold: int = 70


## Nombre total d'ennemis du niveau (toutes vagues).
func enemy_total() -> int:
	var sum := 0
	for wave in enemy_waves:
		sum += wave.total()
	return sum


## Tous les types d'ennemis présents dans le niveau, sans doublon.
func enemy_types() -> Array[String]:
	var out: Array[String] = []
	for wave in enemy_waves:
		for type_name in wave.types():
			if not out.has(type_name):
				out.append(type_name)
	return out


## Un niveau à vagues en couloir : la joueuse doit finir la longueur.
func is_lane() -> bool:
	return layout == "lane"


## L'objectif demande une sortie à atteindre (§ 12.1 et § 12.2 escorte).
func needs_exit() -> bool:
	return objective == "exit" or objective == "escort"


## Nombre d'alliés posés par le niveau (prisonniers + villageois).
func ally_total() -> int:
	return maxi(0, prisoners) + maxi(0, escorts)
