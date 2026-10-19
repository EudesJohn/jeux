extends Node
class_name Objective
## Objectif de niveau (DESIGN.md § 20.10). PHASE 3 en fournit trois :
##  * `ClearWaves` — vider les vagues (« clear ») ;
##  * `Survive` — tenir jusqu'à la fin du temps (« survive », § 12.3) ;
##  * `ReachExit` — atteindre la sortie (« exit », § 12.1).
## Rescue, Escort et KillBoss arrivent en PHASE 4 et 6 (§ 12.2).

var data: LevelData = null
var level: Node = null


func setup(level_data: LevelData, level_node: Node) -> void:
	data = level_data
	level = level_node


## Branchements (signaux). Appelé après `setup`, une fois le niveau prêt.
func start() -> void:
	pass


## Suivi par frame, appelé par le niveau.
func process_level(_delta: float) -> void:
	pass


## Objectif rempli ?
func success() -> bool:
	return false


## Objectif devenu IMPOSSIBLE (§ 12.2 : un villageois escorté qui meurt) ?
## Le niveau échoue aussitôt, sans attendre la fin du temps.
func failed() -> bool:
	return false


## Raison affichée sur l'écran de défaite quand `failed()` est vrai.
func failure_reason() -> String:
	return "objectif"


## Le temps écoulé est-il une RÉUSSITE ? (Survie : oui.)
func time_up_is_success() -> bool:
	return false


## Bonus des 3 étoiles (§ 13).
func bonus_achieved() -> bool:
	return false


## Texte du HUD (§ 16 : « objectif »).
func description() -> String:
	return "Objectif"


## Pourcentage d'avancement (0-1), pour le HUD et les tests.
func progress() -> float:
	return 0.0
