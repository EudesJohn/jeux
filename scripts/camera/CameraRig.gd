extends Node3D
class_name CameraRig
## Caméra automatique (DESIGN.md § 3.2 et § 20.6), pilotée au doigt par le jeu
## (aucun contrôle de caméra pour le joueur).
##
## * LANE : suit le centre des joueurs, décalage (0, 4,5, 7,5), FOV 50.
## * ARENA (PHASE 2) : distance 7 m, hauteur 4 m, FOV 55, placée derrière la
##   joueuse dans l'axe joueuse → cible verrouillée. Verrouillage automatique sur
##   l'ennemi le plus proche (8 m) avec priorité à celui qui attaque ; on change
##   de cible en TOUCHANT un ennemi à l'écran, et automatiquement si elle meurt.
##   Un anneau doré marque la cible (TargetRing).
##
## Le tremblement (hit-stop visuel) est déclenché par FX.shake().

enum Mode { LANE, ARENA }

@export var mode: Mode = Mode.LANE
@export var lane_offset: Vector3 = Vector3(0.0, 4.5, 7.5)
@export var arena_distance: float = 7.0
@export var arena_height: float = 4.0
@export var follow_speed: float = 6.0
@export var lock_radius: float = 8.0        ## § 3.2 : cible dans 8 m
@export var auto_lock: bool = true
@export var lock_ring: bool = true

@onready var cam: Camera3D = $Camera3D

var lock_target: Node3D = null
## Coop (§ 22.2) : en ARENA la caméra suit CETTE joueuse (la nôtre), pas la
## première du groupe ; en LANE elle recadre les deux (voir `_process`).
var focus: Node3D = null
var arena_yaw: float = 0.0
var ring: TargetRing = null

var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _lock_check: float = 0.0            ## ré-évaluation périodique de la cible


func _ready() -> void:
	FX.camera_rig = self
	FX.camera = cam
	cam.fov = 50.0 if mode == Mode.LANE else 55.0
	if mode == Mode.ARENA and lock_ring:
		ring = TargetRing.new()
		ring.name = "TargetRing"
		add_child(ring)
		ring.visible = false


func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("players")
	if players.is_empty():
		# Personne à suivre : on reste où on est (scène de test seule).
		return
	# § 22.2 : le centre est la moyenne des joueuses (identique en solo).
	var center := Vector3.ZERO
	for node in players:
		center += (node as Node3D).global_position
	center = center / float(players.size()) + Vector3(0, 1.0, 0)
	var desired_pos: Vector3

	match mode:
		Mode.LANE:
			# Zoom arrière si les deux joueurs s'écartent (coop, § 3.2).
			var spread := _spread_of(players)
			center += Vector3(0, 0, clampf(spread * 0.4, 0.0, 3.0))
			if spread > 0.0:
				center -= Vector3(0, spread * 0.1, 0)
			desired_pos = center + lane_offset
		Mode.ARENA:
			desired_pos = _arena_position(_focus_node(players), delta, center)

	cam.global_position = cam.global_position.lerp(desired_pos, 1.0 - exp(-follow_speed * delta))
	cam.look_at(center, Vector3.UP)

	if _shake_time > 0.0:
		_shake_time -= delta
		cam.h_offset = randf_range(-1.0, 1.0) * _shake_strength
		cam.v_offset = randf_range(-1.0, 1.0) * _shake_strength
		if _shake_time <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0

	_update_ring()


# -----------------------------------------------------------------#
#                        MODE ARENA (§ 3.2)                        #
# -----------------------------------------------------------------#

func _arena_position(player: Node3D, delta: float, center: Vector3) -> Vector3:
	if auto_lock:
		_update_lock_target(player, delta)

	var yaw := arena_yaw
	if is_instance_valid(lock_target):
		var to_target := lock_target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length() > 0.1:
			# Caméra derrière la joueuse, alignée sur la ligne joueuse → cible.
			yaw = lerp_angle(yaw, atan2(to_target.x, to_target.z), 1.0 - exp(-4.0 * delta))
			center = (player.global_position + lock_target.global_position) * 0.5 + Vector3(0, 1.0, 0)
	else:
		# Sans cible : la caméra suit lentement la direction de déplacement.
		var velocity := (player as CharacterBody3D).velocity if player is CharacterBody3D else Vector3.ZERO
		velocity.y = 0.0
		if velocity.length() > 0.5:
			yaw = lerp_angle(yaw, atan2(velocity.x, velocity.z), 1.0 - exp(-1.5 * delta))
	arena_yaw = yaw
	var back := Vector3(sin(arena_yaw), 0.0, cos(arena_yaw)) * arena_distance
	var desired := player.global_position - back
	desired.y = player.global_position.y + arena_height
	return desired


## Choix de la cible : ennemis vivants du groupe « enemies », dans `lock_radius`,
## priorité à celui qui attaque, puis au plus proche (§ 3.2).
func _update_lock_target(player: Node3D, delta: float) -> void:
	_lock_check -= delta
	var current_ok := is_instance_valid(lock_target) and _lockable(lock_target, player)
	if current_ok and _lock_check > 0.0:
		return
	_lock_check = 0.4
	var candidate := _pick_lock_target(player)
	if candidate != lock_target:
		_set_lock_target(candidate)


func _pick_lock_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_distance: float = lock_radius
	var best_attacking := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var actor := enemy as Node3D
		if not _lockable(actor, player):
			continue
		var distance := actor.global_position.distance_to(player.global_position)
		if distance > lock_radius:
			continue
		var attacking := _is_attacking(actor)
		if attacking and not best_attacking:
			best = actor
			best_distance = distance
			best_attacking = true
		elif attacking == best_attacking and distance < best_distance:
			best = actor
			best_distance = distance
	return best


func _lockable(actor: Node3D, player: Node3D) -> bool:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return false
	if actor.get("dead") == true:
		return false
	return actor.global_position.distance_to(player.global_position) <= lock_radius


func _is_attacking(actor: Node) -> bool:
	## Le mannequin/PHASE 3 : `playing_hit` ou un état d'attaque en cours.
	if actor.get("playing_hit") == true:
		return true
	var state: Variant = actor.get("state")
	if state == null:
		return false
	var state_name := str(state)
	return state_name.contains("TELEGRAPH") or state_name.contains("ATTACK")


func _set_lock_target(target: Node3D) -> void:
	## Sans cible, on garde l'orientation actuelle (pas de saut de caméra).
	lock_target = target
	Events.lock_on_changed.emit(target)


func _update_ring() -> void:
	if ring == null:
		return
	if not is_instance_valid(lock_target):
		ring.visible = false
		return
	ring.visible = true
	ring.global_position = lock_target.global_position + Vector3(0.0, 0.06, 0.0)


# -----------------------------------------------------------------#
#                   CHANGER DE CIBLE AU DOIGT                      #
# -----------------------------------------------------------------#

## § 3.2 : « toucher un ennemi à l'écran change la cible verrouillée ».
## Les TouchButton consomment leurs propres appuis ; ce qui reste arrive ici.
func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.ARENA or not auto_lock:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_try_lock_at((event as InputEventScreenTouch).position)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		# Le clic émulé d'un doigt ne compte pas : l'appui tactile est déjà lu.
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT \
				and mouse.device != InputEvent.DEVICE_ID_EMULATION:
			_try_lock_at(mouse.position)


func _try_lock_at(screen_position: Vector2) -> void:
	var origin := cam.project_ray_origin(screen_position)
	var direction := cam.project_ray_normal(screen_position)
	var best: Node3D = null
	var best_distance := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node3D):
			continue
		var actor := enemy as Node3D
		if actor.get("dead") == true:
			continue
		var chest: Vector3 = actor.global_position + Vector3(0.0, 1.0, 0.0)
		var closest := Geometry3D.get_closest_point_to_segment(chest, origin, origin + direction * 60.0)
		var miss := closest.distance_to(chest)
		if miss > 1.1:                      # à côté : ce n'est pas un appui sur lui
			continue
		var distance := origin.distance_to(chest)
		if distance < best_distance:
			best_distance = distance
			best = actor
	if best != null:
		_set_lock_target(best)


# -----------------------------------------------------------------#
#                          OUTILS                                  #
# -----------------------------------------------------------------#

func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_time = duration


## La joueuse que la caméra cadre : la nôtre en coop, la première sinon.
func _focus_node(players: Array) -> Node3D:
	if focus != null and is_instance_valid(focus) and players.has(focus):
		return focus
	return players[0] as Node3D


func _spread_of(players: Array) -> float:
	## Écartement des joueurs (coop). 0 en solo.
	if players.size() < 2:
		return 0.0
	return (players[0] as Node3D).global_position.distance_to((players[1] as Node3D).global_position)
