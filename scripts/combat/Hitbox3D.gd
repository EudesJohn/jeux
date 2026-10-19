extends Area3D
class_name Hitbox3D
## Zone qui INFLIGE les dégâts (DESIGN.md § 20.2). Activée pendant la fenêtre de
## coup par l'état ATTAQUE de la joueuse / l'attaque ennemie ; un coup frappe
## une cible au plus une fois par activation.
##
## PHASE 2 ajoute le « game feel » : critiques (8 %, ×1,5, § 8.7), hit-stop,
## tremblement de caméra et particules d'impact. La garde parfaite (§ 8.4) est
## entièrement gérée par le défenseur : la Hitbox n'inflige alors rien.

signal hit_landed(target: Node, damage: float)

@export var damage: float = 10.0
@export var knockback: float = 1.2   # m
@export var hitstop: float = 0.05
@export var shake_strength: float = 0.12
@export var is_heavy: bool = false
@export var crit_chance: float = 0.08
@export var crit_mult: float = 1.5

var owner_actor: Node = null
var already_hit: Array[Node] = []
## Dernier coup porté : lisible par les tests et par l'attaquant.
var last_critical: bool = false
var last_amount: float = 0.0


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	monitoring = false


func activate() -> void:
	## Début de la fenêtre du coup : on re-autorise les cibles.
	already_hit.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false


func _on_area_entered(area: Area3D) -> void:
	if not (area is Hurtbox3D):
		return
	if area.owner_actor == owner_actor or already_hit.has(area.owner_actor):
		return
	# § 12.2 : pas de tir ami — les prisonniers et les villageois encaissent les
	# pièges, jamais les coups de la joueuse.
	if area.owner_actor.get("is_ally") == true:
		return
	already_hit.append(area.owner_actor)

	# Critique : 8 % de base, ×1,5 dégâts, étincelle dorée (§ 8.7).
	last_critical = randf() < crit_chance
	last_amount = damage * (crit_mult if last_critical else 1.0)

	var info := DamageInfo.new()
	info.amount = last_amount
	info.knockback = knockback
	info.source_position = global_position
	info.source_actor = owner_actor
	info.is_heavy = is_heavy
	info.is_critical = last_critical

	# § 22.1 : seul l'hôte applique les dégâts. Les coups de l'invitée lui sont
	# envoyés (les ennemis et leur vie appartiennent à l'hôte).
	if Network.is_coop() and not Network.is_host() and owner_actor is Player3D:
		Network.request_hit.rpc_id(1, area.get_path(), info.amount, info.knockback,
			info.is_heavy, info.is_critical)
		hit_landed.emit(area.owner_actor, last_amount)
		return

	var result: int = area.receive_hit(info)
	if result == Hurtbox3D.Result.DODGED:
		return
	hit_landed.emit(area.owner_actor, last_amount)
	if result == Hurtbox3D.Result.PERFECT_GUARD:
		# Rien à frapper : le défenseur a annulé le coup et riposte (§ 8.4).
		return
	FX.hit_feedback(_world(), area.global_position, last_amount,
		"crit" if last_critical else "hit", hitstop, shake_strength)


## Racine du monde où poser particules et nombres flottants (le niveau, le
## mannequin et la joueuse sont tous ses enfants directs).
func _world() -> Node:
	if owner_actor != null and owner_actor.get_parent() != null:
		return owner_actor.get_parent()
	return get_tree().current_scene
