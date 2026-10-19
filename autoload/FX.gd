extends Node
## Effets globaux (DESIGN.md § 20.13) : hit-stop, ralenti, tremblement de caméra
## 3D, particules d'impact et nombres de dégâts. Tous les scripts de combat
## passent par ici (§ 18 règle 3 : un seul point d'entrée pour le « game feel »).
##
## CameraRig s'auto-enregistre dans `camera_rig` à son _ready (PHASE 1).

var camera: Camera3D = null
var camera_rig: Node = null

## Identifiant du dernier gel du temps : seul le plus récent restaure l'échelle
## (deux effets qui se chevauchent ne peuvent plus laisser le jeu figé).
var _freeze_id: int = 0


func hit_stop(duration: float) -> void:
	## Micro-pause à l'impact (§ 8.2 : 0,05 s coups 1-2, 0,09 s coup 3, 0,15 sp.).
	if duration <= 0.0:
		return
	_freeze(0.05, duration)


func slow_motion(scale: float, duration: float) -> void:
	## Ralenti : esquive parfaite et garde parfaite (§ 8.3-8.4), boss (§ 10).
	_freeze(scale, duration)


func _freeze(scale: float, duration: float) -> void:
	_freeze_id += 1
	var my_id := _freeze_id
	Engine.time_scale = clampf(scale, 0.01, 1.0)
	# ignore_time_scale : la minuterie court en temps réel, sinon elle se
	# ralentirait elle-même (0,05 × 0,3 s = 6 s de jeu figé).
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _freeze_id:
		Engine.time_scale = 1.0


func shake(strength: float, duration: float = 0.16) -> void:
	## Tremblement délégué à la caméra 3D active (§ 20.6).
	if camera_rig and camera_rig.has_method("shake"):
		camera_rig.shake(strength, duration)


## Particules d'impact (§ 28). `kind` : "hit", "crit", "block", "perfect",
## "special", "hurt". `world` = un Node3D du monde (pas le personnage).
func impact(world: Node, position: Vector3, kind: String = "hit",
		scale_mult: float = 1.0) -> void:
	ImpactFX.spawn(world, position, kind, scale_mult)


## Nombre de dégâts flottant (§ 16). `kind` : "normal", "crit", "block", "heal".
func damage_number(world: Node, position: Vector3, amount: float,
		kind: String = "normal") -> void:
	DamageNumber.spawn(world, position, amount, kind)


## Effet complet d'un coup porté : hit-stop, tremblement, particules et nombre.
## Centralisé ici pour que la joueuse et les ennemis « claquent » pareil (§ 2).
func hit_feedback(world: Node, position: Vector3, amount: float, kind: String,
		hitstop: float, shake_strength: float) -> void:
	impact(world, position, kind)
	damage_number(world, position + Vector3(0.0, 0.9, 0.0), amount,
		"crit" if kind == "crit" else "normal")
	if shake_strength > 0.0:
		shake(shake_strength)
	if hitstop > 0.0:
		hit_stop(hitstop)
