extends Objective
class_name EscortObjective
## Objectif « escort » (§ 12.2 Escorte, PHASE 4) : conduire le(s) villageois
## jusqu'à la sortie. « S'il meurt = échec » : `failed()` le constate et le
## niveau s'arrête aussitôt, sans attendre la fin du temps.
##
## Réussite : tous les villageois sont vivants ET à portée de la sortie (3 m).
## Étoiles : ★★★ si personne n'a été blessé en chemin.

const EXIT_RADIUS: float = 3.0

func villagers() -> Array[Node]:
	var out: Array[Node] = []
	if level == null or not level.has_method("escort_nodes"):
		return out
	for node in level.call("escort_nodes"):
		out.append(node)
	return out


func total() -> int:
	return villagers().size()


func alive_count() -> int:
	var count := 0
	for villager in villagers():
		if is_instance_valid(villager) and villager.get("dead") != true:
			count += 1
	return count


func hurt_count() -> int:
	var count := 0
	for villager in villagers():
		if is_instance_valid(villager) and villager.get("hurt") == true:
			count += 1
	return count


## Position de la sortie, lue chez le niveau (jamais recalculée ici).
func exit_position() -> Vector3:
	if level == null or level.get("exit_area") == null:
		return Vector3.INF
	return (level.get("exit_area") as Node3D).global_position


func at_exit() -> int:
	var count := 0
	var at := exit_position()
	if at == Vector3.INF:
		return 0
	for villager in villagers():
		if not is_instance_valid(villager) or villager.get("dead") == true:
			continue
		if (villager as Node3D).global_position.distance_to(at) <= EXIT_RADIUS:
			count += 1
	return count


func success() -> bool:
	return total() > 0 and alive_count() == total() and at_exit() == total()


func failed() -> bool:
	return total() > 0 and alive_count() < total()


func failure_reason() -> String:
	return "villageois"


func progress() -> float:
	if total() <= 0:
		return 0.0
	if success():
		return 1.0
	if level == null:
		return 0.0
	var length := float(data.length_m) if data != null else 0.0
	if length <= 0.0:
		return 0.0
	var position: Vector3 = level.call("player_position")
	return clampf(position.x / length, 0.0, 0.99)


func bonus_achieved() -> bool:
	return success() and hurt_count() == 0


func description() -> String:
	if total() > 0 and alive_count() < total():
		return "Villageois perdu"
	return "Escorter le villageois jusqu'à la sortie (%d/%d)" % [at_exit(), total()]
