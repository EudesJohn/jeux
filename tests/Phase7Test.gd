extends Node
## Test fonctionnel de la PHASE 7 (DESIGN.md § 22) :
##   godot --headless --path . res://tests/Phase7Test.tscn
##
## Le test vérifie la coop **sans second téléphone** : il ouvre un vrai serveur
## ENet (aucun client) pour que `Network.is_coop()` et `Network.is_host()` soient
## vrais, puis charge un niveau coop et contrôle :
##   * la joueuse unique de la scène remplacée par celle du réseau (§ 22.1) ;
##   * le `MultiplayerSpawner` + `MultiplayerSynchronizer` d'une joueuse et d'un
##     ennemi (les nœuds qui existent chez l'hôte et chez l'invitée) ;
##   * la difficulté coop du § 22.3 : ×1,3 ennemis, 6 à l'écran, ×1,5 en vie ;
##   * la chute d'une joueuse : 10 s de réanimation, pas de mort immédiate ;
##   * le retour au solo (aucune régression hors coop).
##
## L'échange réel entre deux machines se teste avec `tests/Phase7Net.tscn`
## (deux instances headless sur localhost, voir README § « Tester la coop »).
##
## Sortie : « PHASE 7 : OK » (code 0) ou la liste des échecs (code 1).

const LEVEL_SCENE: String = "res://scenes/levels/LevelBase3D.tscn"
const COOP_LANE: String = "res://data/levels/lane_02.tres"
const COOP_ARENA: String = "res://data/levels/arena_01.tres"
const TEST_PORT: int = 7791
const FROZEN_WAVES: float = 1000.0

var failures: int = 0
var checks: int = 0
var skipped: int = 0
var level: LevelBase3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== Test fonctionnel PHASE 7 (coop) ===")
	var only := OS.get_environment("PHASE7_ONLY")
	var sections: Dictionary = {
		"helpers": _test_helpers,
		"host": _test_coop_host,
		"downed": _test_downed,
		"solo": _test_solo_after_coop,
	}
	for name in sections.keys():
		if only != "" and not only.split(",").has(name):
			continue
		await (sections[name] as Callable).call()
	await _free_level()
	print("--------------------------------")
	print("Vérifications : %d   Échecs : %d   Ignorées : %d" % [checks, failures, skipped])
	print("PHASE 7 : %s" % ("OK" if failures == 0 else "ÉCHECS"))
	get_tree().quit(1 if failures > 0 else 0)


# -----------------------------------------------------------------#
#                        OUTILS DE TEST                            #
# -----------------------------------------------------------------#

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  ok    ", label)
	else:
		failures += 1
		print("  ÉCHEC ", label)


func _skip(label: String) -> void:
	skipped += 1
	print("  ignoré ", label)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _open_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(TEST_PORT, 1)
	_check(error == OK, "serveur ENet de test ouvert (port %d)" % TEST_PORT)
	multiplayer.multiplayer_peer = peer
	Network._connect_signals()


func _close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	Network.leave()


func _free_level() -> void:
	if level != null and is_instance_valid(level):
		if level.spawner != null:
			level.spawner.finished = true
		level.queue_free()
		level = null
		await _frames(4)


func _load_level(path: String) -> LevelBase3D:
	await _free_level()
	# `_ready` du test tourne encore dans `add_child()` de la racine : la racine
	# refuse un enfant tant qu'elle installe les siens. Une frame et c'est fini.
	await _frames(1)
	var scene := load(LEVEL_SCENE).instantiate() as LevelBase3D
	scene.level_data = load(path) as LevelData
	scene.wave_delay_multiplier = FROZEN_WAVES
	get_tree().root.add_child(scene)
	level = scene
	await _frames(6)
	return scene


func _players() -> Array:
	return get_tree().get_nodes_in_group("players")


# -----------------------------------------------------------------#
#                   RÉGLAGES HORS LIGNE (§ 22.3)                   #
# -----------------------------------------------------------------#

func _test_helpers() -> void:
	print("• réseau : valeurs hors ligne et découverte")
	_check(not Network.is_coop(), "hors ligne, is_coop() est faux")
	_check(Network.coop_count_mult() == 1.0, "hors ligne, les vagues ne sont pas multipliées")
	_check(Network.coop_max_on_screen() == 5, "hors ligne, 5 ennemis à l'écran")
	var ids := Network.coop_player_ids()
	_check(ids.size() == 1 and ids[0] == 1, "hors ligne, une seule joueuse (id 1)")
	_check(not Network.get_local_ip().is_empty(), "IP locale lisible pour le lobby")
	_check(Network.GAME_PORT == 7777 and Network.MAX_CLIENTS == 1,
		"port 7777 et 2 joueuses maximum (§ 22)")

	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.type = "soldier"
	entry.count = 3
	wave.enemies = [entry] as Array[SpawnEntry]
	_check(wave.enemies[0].count == 3, "fiche de vague construite pour le test")


# -----------------------------------------------------------------#
#                  NIVEAU COOP CHEZ L'HÔTE (§ 22.1)                #
# -----------------------------------------------------------------#

func _test_coop_host() -> void:
	print("• coop : niveau construit chez l'hôte")
	await _open_server()
	_check(Network.is_coop(), "serveur ouvert : une partie est en cours")
	_check(Network.is_host(), "l'hôte simule (§ 22.1)")
	_check(Network.coop_count_mult() > 1.29, "coop : ennemis ×1,3 (§ 22.3)")
	_check(Network.coop_max_on_screen() == 6, "coop : 6 ennemis à l'écran (§ 22.3)")
	GameState.mode = GameState.GameMode.COOP
	_check(GameState.coop_health_mult() > 1.49, "coop : vie des ennemis ×1,5 (§ 22.3)")
	GameState.mode = GameState.GameMode.NONE
	_check(Network.coop_player_ids().size() == 1, "hôte seul : une joueuse pour l'instant")

	await _load_level(COOP_ARENA)
	_check(level.coop != null, "le niveau crée son CoopDirector")
	var player := level.player
	_check(player != null, "l'hôte a sa joueuse")
	_check(player != null and player.peer_id == 1, "la joueuse de l'hôte est l'id 1")
	_check(player != null and player.is_local_authority(), "elle écoute les entrées")
	_check(_players().size() == 1, "une seule joueuse dans le groupe « players »")
	_check(level.camera_rig != null and level.camera_rig.focus == player,
		"la caméra suit la joueuse locale (§ 22.2)")
	_check(level.hud != null and level.hud.player == player, "le HUD lit la bonne joueuse")
	_check(level.spawner != null and not level.spawner.finished,
		"chez l'hôte, les vagues tournent")

	var sync := player.get_node_or_null("Sync") as MultiplayerSynchronizer
	_check(sync != null, "la joueuse publie son état (MultiplayerSynchronizer)")
	_check(sync != null and sync.root_path == NodePath(".."),
		"le synchroniseur est branché sur la joueuse")
	_check(sync != null and sync.replication_config != null
		and sync.replication_config.property_get_replication_mode(NodePath(".:net_position"))
			== SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		"la position passe par `net_position` (lissage, 20 Hz)")

	# § 22.3 : « nombre d'ennemis ×1,3 » — 5 → 7 (arrondi au supérieur).
	_check(level.spawner._count_for(5) == 7, "une vague de 5 ennemis en compte 7 en coop")
	var scaled: WaveData = level.spawner._scaled(_sample_wave(3))
	_check(scaled != null and scaled.enemies[0].count == 4, "les vagues écrites sont mises à l'échelle")

	# § 22.1 : les ennemis naissent chez l'hôte, par le MultiplayerSpawner.
	var enemy := level.coop.spawn_enemy("soldier", Vector3(4.0, 0.1, 0.0))
	_check(enemy != null, "un ennemi naît à la demande de l'hôte")
	_check(enemy != null and enemy.get_parent() == level.entities_root,
		"il est posé dans `Entities` (racine répliquée)")
	_check(enemy != null and enemy.get_node_or_null("Sync") != null,
		"il est répliqué chez l'invitée (synchroniseur)")
	_check(enemy != null and enemy.net_position != Vector3.ZERO,
		"sa position réseau est initialisée")

	# L'hôte applique bien les dégâts (il est autoritaire).
	if enemy != null:
		var info := DamageInfo.new()
		info.amount = 10.0
		var before := enemy.health
		var result := enemy.on_hit_received(info)
		_check(result != Hurtbox3D.Result.DODGED and enemy.health < before,
			"chez l'hôte, un coup retire de la vie")


func _sample_wave(count: int) -> WaveData:
	var wave := WaveData.new()
	var entry := SpawnEntry.new()
	entry.type = "soldier"
	entry.count = count
	wave.enemies = [entry] as Array[SpawnEntry]
	wave.delay = 1.0
	wave.start_delay = 0.5
	return wave


# -----------------------------------------------------------------#
#              CHUTE ET RÉANIMATION (§ 22.3)                       #
# -----------------------------------------------------------------#

func _test_downed() -> void:
	print("• coop : une joueuse tombe, 10 s pour la relever")
	if level == null:
		await _load_level(COOP_ARENA)
	var player := level.player
	_check(player != null, "joueuse de l'hôte toujours là")
	if player == null:
		_skip("chute : pas de joueuse")
		return
	_check(not level.failed, "le niveau n'a pas encore échoué")
	player.go_down()
	await _frames(2)
	_check(player.downed, "la joueuse est à terre, pas morte")
	_check(player.state == Player3D.State.DEAD, "elle est hors de combat (les ennemis l'ignorent)")
	_check(not level.failed, "tomber ne termine pas le niveau tout de suite")
	_check(player.peer_id in level.coop.downed_peers(), "l'hôte a lancé le décompte de 10 s")

	# Relever : « Interaction » maintenue 2 s à portée (§ 22.3). Ici l'hôte est
	# seul, donc on appelle directement la reprise du niveau.
	level.coop._do_revive(player.peer_id, player)
	await _frames(2)
	_check(not player.downed, "la joueuse est relevée")
	_check(player.health > 0.0, "elle repart avec un peu de vie (30 %)")
	_check(not level.failed, "le niveau continue après la réanimation")

	# Et si personne ne la relève, le décompte échoue le niveau.
	player.go_down()
	await _frames(2)
	level.coop._tick_down(CoopDirector.DOWNED_WINDOW + 1.0)
	await _frames(2)
	_check(level.failed, "sans secours au bout de 10 s, le niveau échoue")


# -----------------------------------------------------------------#
#                   RETOUR AU SOLO (pas de régression)             #
# -----------------------------------------------------------------#

func _test_solo_after_coop() -> void:
	print("• hors ligne : le jeu redevient solo")
	_close_connection()
	_check(not Network.is_coop(), "connexion fermée : is_coop() est faux")
	await _load_level(COOP_LANE)
	_check(level.coop == null, "aucun CoopDirector hors coop")
	_check(level.player != null, "la joueuse de la scène est de retour")
	_check(level.player != null and level.player.peer_id == 1, "elle appartient à l'id 1")
	_check(level.camera_rig != null and level.camera_rig.focus == level.player,
		"la caméra la suit")
	_check(Network.coop_count_mult() == 1.0, "les vagues reprennent leur taille normale")
	_check(level.spawner != null and not level.spawner.finished,
		"le spawner solo tourne")
