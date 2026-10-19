extends Objective
class_name RescueObjective
## Objectif « rescue » (§ 12.2 Sauvetage, PHASE 4) : libérer TOUS les
## prisonniers du niveau par l'interaction de 2 s.
##
## Le niveau pose les cages : l'objectif ne fait que compter, comme `ClearWaves`
## lit le spawner (une seule source de vérité, testable sans jouer).
##
## Étoiles (§ 13) : ★★★ si aucun prisonnier n'a été blessé.

## Les prisonniers encore utiles : les morts ne peuvent plus être libérés.
func prisoners() -> Array[Node]:
	var out: Array[Node] = []
	if level == null or not level.has_method("prisoner_nodes"):
		return out
	for node in level.call("prisoner_nodes"):
		out.append(node)
	return out


func total() -> int:
	return prisoners().size()


func freed_count() -> int:
	var count := 0
	for prisoner in prisoners():
		if is_instance_valid(prisoner) and prisoner.get("freed_flag") == true:
			count += 1
	return count


## Un prisonnier tué rend l'objectif impossible : le niveau échoue (§ 12.2).
func any_down() -> bool:
	for prisoner in prisoners():
		if is_instance_valid(prisoner) and prisoner.get("dead") == true:
			return true
	return false


func hurt_count() -> int:
	var count := 0
	for prisoner in prisoners():
		if is_instance_valid(prisoner) and prisoner.get("hurt") == true:
			count += 1
	return count


func success() -> bool:
	return total() > 0 and freed_count() == total() and not any_down()


func failed() -> bool:
	return any_down()


func failure_reason() -> String:
	return "prisonnier"


func progress() -> float:
	if total() <= 0:
		return 0.0
	return clampf(float(freed_count()) / float(total()), 0.0, 1.0)


func bonus_achieved() -> bool:
	return success() and hurt_count() == 0


func description() -> String:
	return "Libérer les prisonniers (%d/%d)" % [freed_count(), total()]
