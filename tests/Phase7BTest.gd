extends Node
## Test fonctionnel de l'ANNEXE PHASE 7B :
##   godot --headless --path . res://tests/Phase7BTest.tscn
##
## Vérifie sur les artefacts réels :
##   * la foule : 60 / 150 / 300 spectateurs, UN seul MultiMesh, densité ;
##   * la jauge d'excitation : montée, plafond, retombée, audio ;
##   * la caméra spectateur : AUTO, FREE, CROWD ;
##   * les rôles joueur / spectateur décidés par l'hôte (§2.6).
##
## Sortie : « PHASE 7B : OK » (code 0) ou la liste des échecs (code 1).

var failures: int = 0
var checks: int = 0


func _ready() -> void:
	print("=== Test fonctionnel PHASE 7B ===")
	await _test_crowd()
	await _test_excitement()
	await _test_arena()
	await _test_spectator_camera()
	_test_roles()

	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d" % [checks, failures])
	print("PHASE 7B : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _test_crowd() -> void:
	print("- Foule MultiMesh (§2.3)")
	_check(CrowdManager.target_count(0.25) == 60, "Faible : 60 spectateurs")
	_check(CrowdManager.target_count(0.5) == 150, "Moyenne : 150 spectateurs")
	_check(CrowdManager.target_count(1.0) == 300, "Haute : 300 spectateurs")
	var shader := load("res://shaders/crowd.gdshader") as Shader
	_check(shader != null, "shader de foule présent")

	var saved_quality := Settings.quality
	Settings.quality = "medium"
	var manager := CrowdManager.new()
	manager.name = "CrowdManager"
	manager.crowd_material = ShaderMaterial.new()
	add_child(manager)
	await _frames(2)

	_check(manager.crowd_size() == 150, "densité Moyenne construite au démarrage")
	_check(_mesh_count(manager) == 1, "un seul MultiMeshInstance3D")
	var mm_instance := manager.multimesh_instance
	_check(mm_instance.multimesh.use_colors, "couleur par instance")
	_check(mm_instance.multimesh.use_custom_data, "phase de rebond par instance")
	_check(mm_instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"la foule ne projette pas d'ombre")

	manager.build_crowd(0.25)
	await _frames(2)
	_check(manager.crowd_size() == 60, "reconstruction en Faible : 60")
	manager.build_crowd(1.0)
	await _frames(2)
	_check(manager.crowd_size() == 300, "reconstruction en Haute : 300")
	_check(_mesh_count(manager) == 1, "toujours un seul appel de dessin")
	mm_instance = manager.multimesh_instance
	_check(mm_instance.multimesh.instance_count == 300, "300 instances dans le MultiMesh")

	# Le rendu « dummy » ne conserve pas les transformations : on vérifie la
	# fonction de placement elle-même, qui est celle utilisée par le MultiMesh.
	var seats := CrowdManager.seat_transforms(300, 6, 15.0, 1.1, 0.9)
	_check(seats.size() == 300, "300 sièges placés")
	var first := seats[0].origin
	var last := seats[299].origin
	_check(absf(Vector2(first.x, first.z).length() - 15.0) < 0.01,
		"première rangée à 15 m du centre")
	_check(Vector2(last.x, last.z).length() > Vector2(first.x, first.z).length(),
		"les rangées montent vers l'extérieur")

	manager.queue_free()
	await _frames(2)
	Settings.quality = saved_quality


func _mesh_count(manager: CrowdManager) -> int:
	var count := 0
	for child in manager.get_children():
		if child is MultiMeshInstance3D:
			count += 1
	return count


func _test_excitement() -> void:
	print("- Jauge d'excitation (§2.3)")
	var manager := CrowdManager.new()
	manager.crowd_material = ShaderMaterial.new()
	add_child(manager)
	await _frames(2)

	_check(is_equal_approx(manager.excitement, 0.2), "départ à 0,2")
	Events.crowd_event.emit(0.3)
	_check(is_equal_approx(manager.excitement, 0.5), "un événement fait monter la jauge")
	Events.crowd_event.emit(0.9)
	_check(is_equal_approx(manager.excitement, 1.0), "jauge plafonnée à 1,0")
	_check(is_equal_approx(AudioManager.crowd_level, 1.0), "niveau audio transmis")

	manager._process(4.0)
	_check(manager.excitement < 1.0, "la jauge retombe")
	manager._process(60.0)
	_check(is_equal_approx(manager.excitement, 0.2), "plancher à 0,2")
	manager.cheer(0.12)
	_check(is_equal_approx(manager.excitement, 0.32), "cheer() passe par le signal")

	manager.queue_free()
	await _frames(2)


func _test_arena() -> void:
	print("- Arène jouable (§2.2)")
	var saved_quality := Settings.quality
	Settings.quality = "medium"
	var scene := load("res://scenes/levels/Arena3D.tscn") as PackedScene
	var arena := scene.instantiate() as Arena3D
	add_child(arena)
	await _frames(3)
	_check(arena is Arena3D, "scène d'arène chargée")
	_check(arena.spawn_count() == 4, "4 points d'apparition")
	_check(arena.spawn_position(0).length() > 7.0, "apparition à 8 m du centre")
	_check(arena.floor_mesh != null, "sol construit")
	_check(arena.crowd != null and arena.crowd.crowd_size() == 150,
		"foule de 150 spectateurs dans l'arène")
	var meshes := 0
	for child in arena.get_children():
		if child is MultiMeshInstance3D:
			meshes += 1
		if child is CrowdManager:
			for sub in child.get_children():
				if sub is MultiMeshInstance3D:
					meshes += 1
	_check(meshes == 1, "un seul MultiMesh pour toute la foule")
	_check(arena.get_node_or_null("Tribune") != null, "tribune présente")
	arena.queue_free()
	await _frames(2)
	Settings.quality = saved_quality


func _test_spectator_camera() -> void:
	print("- Caméra spectateur (§2.8)")
	var camera := SpectatorCamera.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	camera.add_child(cam)
	add_child(camera)
	var fighter_a := Node3D.new()
	fighter_a.position = Vector3(-2.0, 0.0, 0.0)
	add_child(fighter_a)
	fighter_a.add_to_group("players")
	var fighter_b := Node3D.new()
	fighter_b.position = Vector3(4.0, 0.0, 0.0)
	add_child(fighter_b)
	fighter_b.add_to_group("players")
	await _frames(3)
	camera._process(0.2)
	_check(camera.has_fighters, "deux combattants détectés")
	_check(cam.global_position.length() > 0.5, "la caméra s'approche du centre")

	camera.mode = SpectatorCamera.Mode.CROWD
	for _i in 5:
		camera._process(0.2)
	var to_center := (Vector3(2.0, 0.0, 0.0) - cam.global_position).normalized()
	_check((-cam.global_transform.basis.z).dot(to_center) > 0.9,
		"mode Foule : regarde le centre")

	camera.mode = SpectatorCamera.Mode.FREE
	var yaw_before := camera.yaw
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(40.0, 10.0)
	camera._input(drag)
	_check(camera.yaw != yaw_before, "mode Libre : le glissement orbite")
	var pitch_before := camera.pitch
	camera._input(drag)
	_check(camera.pitch < pitch_before, "le glissement vertical incline la caméra")

	camera.mode = SpectatorCamera.Mode.AUTO
	_check(camera.cycle_mode() == SpectatorCamera.Mode.FREE, "cycle des trois modes")
	camera.queue_free()
	fighter_a.queue_free()
	fighter_b.queue_free()
	await _frames(2)


func _test_roles() -> void:
	print("- Rôles joueur / spectateur (§2.6)")
	_check(Network.MAX_PLAYERS == 2, "2 joueurs maximum")
	_check(Network.MAX_SPECTATORS == 4, "4 spectateurs maximum")
	_check(Network.decide_role(Network.Role.PLAYER, 0, 0) == Network.Role.PLAYER,
		"première place = joueur")
	_check(Network.decide_role(Network.Role.PLAYER, 1, 0) == Network.Role.PLAYER,
		"deuxième place = joueur")
	_check(Network.decide_role(Network.Role.PLAYER, 2, 0) == Network.Role.SPECTATOR,
		"joueurs pleins : le troisième devient spectateur")
	_check(Network.decide_role(Network.Role.PLAYER, 2, 4) == -1,
		"partie pleine : refus")
	_check(Network.decide_role(Network.Role.SPECTATOR, 0, 0) == Network.Role.SPECTATOR,
		"un spectateur volontaire reste spectateur")

	_check(Network.role_of(1) == Network.Role.PLAYER, "l'hôte est joueur")
	_check(not Network.is_spectator(1), "l'hôte n'est pas spectateur")
	_check(Network.is_spectator(42), "un pair inconnu est spectateur par défaut")
	_check(Network.player_roles() == [1], "un seul joueur au départ")

	var granted := [-1]
	var full := [false]
	Events.role_assigned.connect(func(role: int) -> void: granted[0] = role)
	Events.lobby_full.connect(func() -> void: full[0] = true)
	Network.role_granted(Network.Role.SPECTATOR)
	_check(granted[0] == Network.Role.SPECTATOR, "le rôle accordé est annoncé")
	Network.kick_full()
	_check(full[0], "la partie pleine est annoncée")
	Network.roles = {1: Network.Role.PLAYER}
