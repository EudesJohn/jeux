extends Node
## Test coop à DEUX INSTANCES (DESIGN.md § 22) : le même script joue l'hôte ou
## l'invitée selon `PHASE7_ROLE`, sur localhost (ENet, port 7777).
##
##   PHASE7_ROLE=guest godot --headless --path . res://tests/Phase7Net.tscn &
##   PHASE7_ROLE=host  godot --headless --path . res://tests/Phase7Net.tscn
##
## Ce que le test prouve, entre deux processus réels :
##   * l'invitée trouve l'hôte, le lobby passe la main, le niveau se charge des
##     deux côtés avec la même fiche ;
##   * deux joueuses existent (`players`), chacune autoritaire chez elle ;
##   * les ennemis naissent chez l'hôte et apparaissent chez l'invitée ;
##   * la position de l'hôte arrive à l'invitée (`net_position`) ;
##   * le timer, lui, vient de l'instantané de l'hôte ;
##   * un coup de l'invitée touche vraiment (aller-retour RPC → vie répliquée),
##     et l'invitée ne peut pas retirer de vie elle-même ;
##   * quitter proprement ne bloque personne.
##
## Le nœud vit sous la racine (`/root/Phase7NetRunner`) : il survit au
## changement de scène déclenché par `Network.launch_coop_level()`.

const LEVEL: String = "res://data/levels/arena_01.tres"
const WAIT_PEER_S: float = 25.0
const WAIT_SCENE_S: float = 20.0
const WAIT_ENEMY_S: float = 10.0

var role: String = ""
var checks: int = 0
var failures: int = 0
var level: LevelBase3D = null
var _guest_done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	role = OS.get_environment("PHASE7_ROLE").strip_edges().to_lower()
	if role != "host" and role != "guest":
		push_error("PHASE7_ROLE doit valoir host ou guest")
		get_tree().quit(2)
		return
	print("=== PHASE 7 réseau (%s) ===" % role)
	if role == "host":
		await _run_host()
	else:
		await _run_guest()
	print("--------------------------------")
	print("[%s] Vérifications : %d   Échecs : %d" % [role, checks, failures])
	print("PHASE 7 RÉSEAU (%s) : %s" % [role, "OK" if failures == 0 else "ÉCHECS"])
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------#
#                            OUTILS                                #
# -----------------------------------------------------------------#

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  [%s] ok    %s" % [role, label])
	else:
		failures += 1
		print("  [%s] ÉCHEC %s" % [role, label])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _wait_until(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()):
			return true
		await get_tree().process_frame
	return bool(condition.call())


func _players() -> Array:
	return get_tree().get_nodes_in_group("players")


func _enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies")


func _scene() -> LevelBase3D:
	return get_tree().current_scene as LevelBase3D


## Le runner est un frère de la scène courante : on l'appelle par RPC pour que
## l'hôte sache quand l'invitée a fini (et ne coupe pas la connexion avant).
@rpc("any_peer", "call_remote", "reliable")
func guest_finished() -> void:
	_guest_done = true


# -----------------------------------------------------------------#
#                              HÔTE                                #
# -----------------------------------------------------------------#

func _run_host() -> void:
	Network.host_game()
	_check(Network.is_coop(), "hôte : partie ouverte (is_coop)")
	_check(Network.is_host(), "hôte : c'est bien le serveur (is_host)")

	var joined := await _wait_until(func() -> bool: return not Network.peer_ids.is_empty(),
		WAIT_PEER_S)
	_check(joined, "hôte : l'invitée s'est connectée")
	if not joined:
		return

	Network.launch_coop_level(LEVEL)
	var loaded := await _wait_until(func() -> bool: return _scene() != null, WAIT_SCENE_S)
	level = _scene()
	_check(loaded and level != null, "hôte : le niveau coop est chargé")

	var both := await _wait_until(func() -> bool: return _players().size() >= 2, WAIT_SCENE_S)
	_check(both, "hôte : deux joueuses dans le niveau")
	if level == null:
		return
	_check(level.coop != null, "hôte : CoopDirector en place")
	_check(level.player != null and level.player.peer_id == 1,
		"hôte : la joueuse locale est l'id 1")
	_check(level.player != null and level.player.is_local_authority(),
		"hôte : elle répond aux entrées")

	var guest: Player3D = null
	for node in _players():
		var candidate := node as Player3D
		if candidate != null and candidate.peer_id != 1:
			guest = candidate
	_check(guest != null, "hôte : la joueuse de l'invitée existe")
	_check(guest != null and not guest.is_local_authority(),
		"hôte : sa copie ne répond pas aux entrées locales")

	# Un ennemi naît chez l'hôte : il doit apparaître chez l'invitée.
	var enemy := level.coop.spawn_enemy("soldier", Vector3(5.0, 0.1, 0.0))
	_check(enemy != null, "hôte : ennemi créé par le MultiplayerSpawner")
	await _wait(0.5)

	# L'hôte bouge : l'invitée doit voir la position arriver (net_position).
	if level.player != null:
		level.player.global_position += Vector3(0.0, 0.0, 1.8)
		level.player.net_position = level.player.global_position
	await _wait(0.6)

	# On laisse l'invitée tester son coup (aller-retour RPC) et son timer.
	var done := await _wait_until(func() -> bool: return _guest_done, 25.0)
	_check(done, "hôte : l'invitée a terminé ses vérifications")
	_check(not level.failed, "hôte : la partie n'a pas échoué pendant le test")


# -----------------------------------------------------------------#
#                            INVITÉE                               #
# -----------------------------------------------------------------#

func _run_guest() -> void:
	Network.join_game("127.0.0.1")
	var connected := await _wait_until(func() -> bool: return Network.is_coop(), WAIT_PEER_S)
	_check(connected, "invitée : connectée à l'hôte")
	if not connected:
		return
	_check(not Network.is_host(), "invitée : ce n'est pas elle qui simule")

	var loaded := await _wait_until(func() -> bool: return _scene() != null, WAIT_SCENE_S)
	level = _scene()
	_check(loaded and level != null, "invitée : le niveau coop est chargé")
	if level == null:
		return

	var both := await _wait_until(func() -> bool: return _players().size() >= 2, WAIT_SCENE_S)
	_check(both, "invitée : deux joueuses dans le niveau")
	_check(level.coop != null, "invitée : CoopDirector en place")

	var local := level.player
	_check(local != null, "invitée : sa joueuse est là")
	_check(local != null and local.peer_id == Network.local_id(),
		"invitée : c'est bien la sienne")
	_check(local != null and local.is_local_authority(),
		"invitée : elle répond à SES entrées")

	var host_player: Player3D = null
	for node in _players():
		var candidate := node as Player3D
		if candidate != null and candidate != local:
			host_player = candidate
	_check(host_player != null, "invitée : la joueuse de l'hôte est visible")
	_check(host_player != null and host_player.peer_id == 1,
		"invitée : elle est attribuée à l'hôte")

	# § 22.1 : les vagues de l'invitée ne tournent pas (sinon deux jeux d'ennemis).
	_check(level.spawner != null and level.spawner.finished,
		"invitée : son spawner ne simule pas les vagues")

	# Position de l'hôte : elle arrive par le réseau et la copie la rattrape.
	var moved := false
	var move_deadline := Time.get_ticks_msec() + int(WAIT_ENEMY_S * 1000.0)
	while Time.get_ticks_msec() < move_deadline:
		if host_player != null and is_instance_valid(host_player) 				and host_player.net_position != Vector3.ZERO 				and host_player.global_position.distance_to(host_player.net_position) < 0.5:
			moved = true
			break
		await get_tree().process_frame
	_check(moved, "invitée : la position de l'hôte arrive et est appliquée")

	# Ennemi de l'hôte : répliqué ici par le MultiplayerSpawner.
	var spawned := await _wait_until(func() -> bool: return not _enemies().is_empty(),
		WAIT_ENEMY_S)
	_check(spawned, "invitée : l'ennemi de l'hôte est répliqué")

	# Timer : le client ne le simule pas, il reçoit l'instantané de l'hôte.
	var before := level.time_left
	await _wait(1.2)
	_check(level.time_left < before, "invitée : le timer vient de l'hôte")

	# L'invitée n'applique aucun dégât elle-même (§ 22.1)…
	if not _enemies().is_empty():
		var enemy := _enemies()[0] as EnemyBase3D
		var hurtbox := enemy.get_node_or_null("Hurtbox3D") as Hurtbox3D
		var info := DamageInfo.new()
		info.amount = 5.0
		var health_before := enemy.health
		var refused := enemy.on_hit_received(info)
		_check(refused == Hurtbox3D.Result.DODGED and is_equal_approx(enemy.health, health_before),
			"invitée : un coup local ne retire pas de vie (l'hôte décide)")
		# …mais son coup part à l'hôte et revient par la réplication.
		if hurtbox != null:
			Network.request_hit.rpc_id(1, hurtbox.get_path(), 5.0, 1.0, false, false)
			var hurt := false
			var hurt_deadline := Time.get_ticks_msec() + 6000
			while Time.get_ticks_msec() < hurt_deadline:
				if is_instance_valid(enemy) and enemy.health < health_before - 0.1:
					hurt = true
					break
				await get_tree().process_frame
			_check(hurt, "invitée : son coup est appliqué par l'hôte (aller-retour RPC)")

	guest_finished.rpc_id(1)
	await _wait(0.3)
