extends Objective
class_name SurviveObjective
## Objectif « survive » (§ 12.3 Survie, PHASE 3) : tenir jusqu'à la fin du temps.
## Le temps écoulé est ici une RÉUSSITE (contrairement aux autres objectifs).

signal survived


func time_up_is_success() -> bool:
	return true


func success() -> bool:
	# § 12.3 : la Survie n'a pas de limite de temps (time_limit = 0) : elle ne
	# se gagne pas, elle se termine quand la joueuse tombe.
	if data != null and data.time_limit <= 0:
		return false
	return level != null and float(level.get("time_left")) <= 0.0


func progress() -> float:
	if data == null or data.time_limit <= 0:
		return 0.0
	var left: float = float(level.get("time_left")) if level != null else 0.0
	return clampf(1.0 - left / float(data.time_limit), 0.0, 1.0)


func description() -> String:
	if data != null and data.time_limit <= 0:
		return "Survie — vague %d" % (waves_survived() + 1)
	return "Tenir jusqu'à la fin du temps"


## Vagues repoussées, pour les tests et l'écran de résultat.
func waves_survived() -> int:
	var spawner := _spawner()
	return spawner.current_wave if spawner != null else 0


func _spawner() -> WaveSpawner3D:
	if level == null:
		return null
	return level.get("spawner") as WaveSpawner3D
