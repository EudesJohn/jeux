extends Area3D
class_name Hurtbox3D
## Zone qui REÇOIT les dégâts (DOSSIER.md § 20.3). Délègue la décision à
## l'acteur propriétaire (jugement esquive/garde/toucher) et émet le signal.

enum Result { HIT, BLOCKED, PERFECT_GUARD, DODGED }

signal damaged(info: DamageInfo, result: int)

var owner_actor: Node = null


func _ready() -> void:
	collision_layer = collision_layer


func receive_hit(info: DamageInfo) -> int:
	if owner_actor and owner_actor.has_method("on_hit_received"):
		var result: int = owner_actor.on_hit_received(info)
		damaged.emit(info, result)
		return result
	return Result.HIT
