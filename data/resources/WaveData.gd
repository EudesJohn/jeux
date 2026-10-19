extends Resource
class_name WaveData
## Une vague d'ennemis (DESIGN.md § 20.11). Contenu en Resource, jamais en dur
## (§ 18 règle 2) : les niveaux sont des fichiers `data/levels/*.tres` que l'on
## modifie sans toucher au code.

## Ennemis lancés ensemble (ex. 3 soldats + 1 éclaireur).
@export var enemies: Array[SpawnEntry] = []
## Temps entre deux apparitions de cette vague (s).
@export var delay: float = 1.2
## Délai avant que la vague ne démarre une fois la précédente nettoyée (s).
@export var start_delay: float = 0.5


## Nombre total d'ennemis de la vague (tests et HUD d'objectif).
func total() -> int:
	var sum := 0
	for entry in enemies:
		sum += maxi(0, entry.count)
	return sum


## Types présents, sans doublon (« soldier », « archer »…).
func types() -> Array[String]:
	var out: Array[String] = []
	for entry in enemies:
		if entry.count > 0 and not out.has(entry.type):
			out.append(entry.type)
	return out
