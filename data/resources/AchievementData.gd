extends Resource
class_name AchievementData
## Fiche d'un succès (PHASE 8). Le suivi est fait par `Achievements` :
## `stat` est la clé du compteur (SaveManager.data["stats"]) et `target` le
## seuil à atteindre. Les .tres vivent dans `data/achievements/`.

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
## Compteur surveillé : kills, perfect_guards, rescued, levels, bosses,
## survival_waves, daily_streak, coop_levels.
@export var stat: String = ""
@export var target: int = 1
## Masqué tant qu'il n'est pas débloqué (succès surprise).
@export var hidden: bool = false


## Part du compteur déjà faite, entre 0 et 1 (pour la barre de l'écran).
func progress_ratio(current: int) -> float:
	if target <= 0:
		return 1.0
	return clampf(float(current) / float(target), 0.0, 1.0)
