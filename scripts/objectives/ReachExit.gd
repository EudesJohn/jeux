extends Objective
class_name ReachExit
## Objectif « exit » (§ 12.1 Aventure, PHASE 3) : atteindre la sortie du niveau.
## C'est `LevelBase3D` qui détecte l'entrée dans la zone de sortie et lève son
## drapeau `exit_reached` ; l'objectif ne fait que le lire (une seule source de
## vérité, testable sans jouer).

func success() -> bool:
	return exit_reached()


func progress() -> float:
	if level == null or data == null or data.length_m <= 0.0:
		return 0.0
	if exit_reached():
		return 1.0
	var position: Vector3 = level.call("player_position")
	return clampf(position.x / maxf(data.length_m, 1.0), 0.0, 1.0)


func description() -> String:
	return "Atteindre la sortie"


func exit_reached() -> bool:
	return level != null and level.get("exit_reached") == true
