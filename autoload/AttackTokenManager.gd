extends Node
## Jeton d'attaque (DOSSIER.md § 9 « Lisibilité 3D ») : au maximum 2 ennemis
## peuvent attaquer simultanément, les autres tournent autour à 3 m (strafing).
## Squelette fonctionnel dès PHASE 1, utilisé par EnemyBase3D (PHASE 3).

const MAX_ATTACKERS: int = 2

var holders: Array[Node] = []


func request(enemy: Node) -> bool:
	if holders.has(enemy):
		return true
	if holders.size() < MAX_ATTACKERS:
		holders.append(enemy)
		return true
	return false


func release(enemy: Node) -> void:
	holders.erase(enemy)
