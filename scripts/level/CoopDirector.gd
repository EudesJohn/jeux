extends Node
class_name CoopDirector
## Coop WiFi (DESIGN.md § 22, PHASE 7) : tout ce qui est réseau vit ici, pour que
## `LevelBase3D`, `Player3D` et `EnemyBase3D` restent lisibles.
##
## Règle du § 22.1 : **l'hôte autoritaire** simule (ennemis, dégâts, objectifs,
## timer) ; l'invitée envoie ses inputs et reçoit l'état. Conséquences :
##  * un seul `WaveSpawner3D` tourne, celui de l'hôte, et il passe par
##    `spawn_enemy()` : les ennemis naissent chez les deux ;
##  * seul l'hôte applique des dégâts (`Hitbox3D` route les coups de l'invitée
##    vers lui) ;
##  * l'hôte envoie un **instantané de niveau** 5 fois par seconde (timer,
##    objectif, boss, prisonniers) : le client ne simule ni le temps ni les
##    objectifs ;
##  * **réanimation** (§ 22.3) : une joueuse à terre, l'autre a 10 s pour la
##    relever (2 s d'interaction) ;
##  * **déconnexion** : message clair, retour au lobby ou poursuite en solo.
##
## La synchro d'entités utilise `MultiplayerSpawner` + `MultiplayerSynchronizer`
## (§ 22.1) à 20 Hz. Godot 4.3 n'interpole pas les synchroniseurs : la position
## des joueuses distantes est lissée par `_smooth_remotes()` (voir la note dans
## le README).

signal local_player_ready(player: Player3D)
signal remote_player_joined(peer_id: int, player: Player3D)
signal remote_player_left(peer_id: int)
signal coop_message(text: String)

const PLAYER_SCENE: String = "res://scenes/characters/Player3D.tscn"
const ENEMY_SCENE: String = "res://scenes/enemies/Enemy3D.tscn"
const SYNC_INTERVAL: float = 0.05          ## 20 Hz (§ 22.1)
const SNAPSHOT_INTERVAL: float = 0.2       ## 5 Hz : assez pour un timer
const DOWNED_WINDOW: float = 10.0          ## § 22.3 : 10 s pour relever
const REVIVE_HOLD: float = 2.0             ## § 22.3 : 2 s d'interaction
const REVIVE_RANGE: float = 2.5
const REVIVE_HEALTH_RATIO: float = 0.3

var level: Node3D = null
var players_root: Node3D = null
var enemies_root: Node3D = null
var players_spawner: MultiplayerSpawner = null
var enemies_spawner: MultiplayerSpawner = null

var local_player: Player3D = null
var players_by_peer: Dictionary = {}       ## peer_id -> Player3D
var downed: Dictionary = {}                ## peer_id -> temps restant
var revive_hold: float = 0.0
var is_host: bool = false

var _snapshot_left: float = 0.0
## Numérote les ennemis : le nom doit être IDENTIQUE chez les deux joueuses, car
## les RPC de dégâts désignent une cible par son chemin de nœud.
var _enemy_serial: int = 0
var _remote_targets: Dictionary = {}       ## Player3D -> position réseau visée


func setup(level_node: Node3D) -> void:
	level = level_node
	is_host = Network.is_host()
	players_root = Node3D.new()
	players_root.name = "Players"
	level.add_child(players_root)

	players_spawner = MultiplayerSpawner.new()
	players_spawner.name = "PlayersSpawner"
	players_spawner.add_spawnable_scene(PLAYER_SCENE)
	players_spawner.spawn_function = _spawn_player_node
	level.add_child(players_spawner)
	players_spawner.spawn_path = players_spawner.get_path_to(players_root)

	var entities: Node3D = level.get("entities_root")
	if entities != null:
		enemies_root = entities
		enemies_spawner = MultiplayerSpawner.new()
		enemies_spawner.name = "EnemiesSpawner"
		enemies_spawner.add_spawnable_scene(ENEMY_SCENE)
		enemies_spawner.spawn_function = _spawn_enemy_node
		level.add_child(enemies_spawner)
		enemies_spawner.spawn_path = enemies_spawner.get_path_to(enemies_root)

	Network.peer_left.connect(_on_peer_left)


## Appelé à la fin de `LevelBase3D.load_level()` : les joueuses apparaissent
## après le décor, aux mêmes endroits des deux côtés.
func start_level() -> void:
	if is_host:
		for id in Network.coop_player_ids():
			players_spawner.spawn({"peer": id})


func local_peer() -> int:
	return Network.local_id()


# -----------------------------------------------------------------#
#                     APPARITION DES JOUEUSES                      #
# -----------------------------------------------------------------#

## Exécutée par le `MultiplayerSpawner` chez TOUT LE MONDE avec les mêmes
## données : chaque copie sait à quelle joueuse elle appartient.
func _spawn_player_node(data: Variant) -> Node:
	var peer := int((data as Dictionary).get("peer", 1))
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player3D
	player.name = "Player_%d" % peer
	player.peer_id = peer
	player.set_multiplayer_authority(peer)
	# `balance` et les `@onready` de la joueuse n'existent qu'une fois le nœud
	# entré dans l'arbre. Le spawner l'ajoute juste après ce retour : on configure
	# donc à `_ready`, pas ici.
	player.ready.connect(_configure_player.bind(player, peer), CONNECT_ONE_SHOT)
	return player


func _configure_player(player: Player3D, peer: int) -> void:
	var data: LevelData = level.get("level_data")
	if data != null:
		player.lane_mode = data.is_lane()
		player.lane_depth = data.lane_half_depth
		player.lane_center_z = 0.0
	player.auto_respawn = false
	player.reset_for_level()
	player.collision_layer = 2

	# Le synchroniseur vit SOUS la joueuse : `..` = la joueuse elle-même. On
	# publie `net_position` (et non `position`) pour que la copie distante puisse
	# glisser vers la valeur reçue au lieu de sauter de 50 ms en 50 ms.
	var synchronizer := MultiplayerSynchronizer.new()
	synchronizer.name = "Sync"
	synchronizer.root_path = NodePath("..")
	synchronizer.replication_interval = SYNC_INTERVAL
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:net_position"))
	config.add_property(NodePath("Visual:rotation:y"))
	config.add_property(NodePath(".:state"))
	config.add_property(NodePath(".:health"))
	config.add_property(NodePath(".:guard_stability"))
	config.property_set_replication_mode(NodePath(".:net_position"),
		SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.property_set_replication_mode(NodePath("Visual:rotation:y"),
		SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.property_set_replication_mode(NodePath(".:state"),
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.property_set_replication_mode(NodePath(".:health"),
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	config.property_set_replication_mode(NodePath(".:guard_stability"),
		SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	synchronizer.replication_config = config
	player.add_child(synchronizer)

	players_by_peer[peer] = player
	if peer == local_peer():
		_announce_local_player(player)
	# Les copies distantes gardent `_physics_process` : c'est là qu'elles lisent
	# `net_position` et glissent vers l'autre téléphone (`Player3D._follow_network`).

	player.tree_exiting.connect(func() -> void: players_by_peer.erase(peer))
	_place_player(player, peer)


## Départ : côte à côte en couloir, en cercle au centre de l'arène.
func _place_player(player: Player3D, peer: int) -> void:
	var data: LevelData = level.get("level_data")
	var base: Vector3 = level.get("spawn_point")
	var index := Network.coop_player_ids().find(peer)
	index = maxi(index, 0)
	var offset := Vector3(0.0, 0.1, 1.4 * float(index)) if (data != null and data.is_lane()) \
		else Vector3(1.4 * float(index), 0.1, 0.0)
	player.global_position = base + offset
	player.velocity = Vector3.ZERO
	player.net_position = player.global_position   # pas de glissade au départ


func _announce_local_player(player: Player3D) -> void:
	level.set("player", player)
	local_player = player
	# Le niveau ne reprend la main (HUD, caméra, nuit) qu'une fois sa joueuse là :
	# `LevelBase3D._on_coop_player_ready` écoute ce signal.
	local_player_ready.emit(player)


# -----------------------------------------------------------------#
#                        ENNEMIS (§ 22.1)                          #
# -----------------------------------------------------------------#

## Les ennemis naissent sur l'hôte et sont répliqués (§ 22.1). Le client ne
## simule rien : sa copie n'a ni IA ni dégâts.
func spawn_enemy(type_name: String, at: Vector3) -> EnemyBase3D:
	if not is_host or enemies_spawner == null:
		return null
	_enemy_serial += 1
	return enemies_spawner.spawn({"type": type_name, "at": at,
		"id": _enemy_serial}) as EnemyBase3D


func _spawn_enemy_node(data: Variant) -> Node:
	var info := data as Dictionary
	var type_name := String(info.get("type", "soldier"))
	var at: Vector3 = info.get("at", Vector3.ZERO)
	var enemy := (load(ENEMY_SCENE) as PackedScene).instantiate() as EnemyBase3D
	enemy.name = "Enemy_%d" % int(info.get("id", 0))
	enemy.data = EnemyRegistry.get_data(type_name)
	enemy.position = at
	var data_level: LevelData = level.get("level_data")
	if data_level != null:
		enemy.lane_mode = data_level.is_lane()
		enemy.lane_depth = data_level.lane_half_depth
		enemy.lane_center_z = 0.0
	# L'hôte possède les ennemis : lui seul décide de leur vie et de leurs coups.
	enemy.set_multiplayer_authority(1)
	enemy.net_position = at

	var synchronizer := MultiplayerSynchronizer.new()
	synchronizer.name = "Sync"
	synchronizer.root_path = NodePath("..")
	synchronizer.replication_interval = SYNC_INTERVAL
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:net_position"))
	config.add_property(NodePath("Visual:rotation:y"))
	config.add_property(NodePath(".:health"))
	config.add_property(NodePath(".:state"))
	config.property_set_replication_mode(NodePath(".:net_position"),
		SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.property_set_replication_mode(NodePath("Visual:rotation:y"),
		SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	synchronizer.replication_config = config
	enemy.add_child(synchronizer)

	return enemy


# -----------------------------------------------------------------#
#                    INSTANTANÉ DE NIVEAU (hôte)                   #
# -----------------------------------------------------------------#

func tick(delta: float) -> void:
	if is_host:
		_snapshot_left -= delta
		if _snapshot_left <= 0.0:
			_snapshot_left = SNAPSHOT_INTERVAL
			_send_snapshot()
		_tick_down(delta)


## § 22.1 : le client ne simule ni le temps ni les objectifs.
func _send_snapshot() -> void:
	var boss: Node = level.get("boss")
	var boss_ratio := 0.0
	if boss != null and is_instance_valid(boss):
		boss_ratio = float(boss.call("health_ratio"))
	_snapshot.rpc(float(level.get("time_left")), bool(level.get("completed")),
		bool(level.get("failed")), boss_ratio, level.call("prisoner_status"))


@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(time_left: float, completed: bool, failed: bool, boss_ratio: float,
		prisoners: Vector2i) -> void:
	level.set("time_left", time_left)
	level.set("_coop_boss_ratio", boss_ratio)
	level.set("_coop_prisoners", prisoners)
	# Le gardien de l'invitée n'est qu'un reflet : sa barre de vie suit l'hôte.
	var local_boss: Node = level.get("boss")
	if local_boss != null and is_instance_valid(local_boss):
		var maximum := float(local_boss.get("max_health"))
		local_boss.set("health", maximum * boss_ratio)
	if completed:
		level.call("_win")
	elif failed and not bool(level.get("failed")):
		level.call("_fail", "hôte")


# -----------------------------------------------------------------#
#                RÉANIMATION ET DÉCONNEXION (§ 22.3)               #
# -----------------------------------------------------------------#

## Une joueuse tombe : on ne termine pas le niveau tout de suite, on laisse
## 10 s à l'autre pour la relever.
func mark_downed(peer: int) -> void:
	if not is_host:
		return
	downed[peer] = DOWNED_WINDOW
	_revive.rpc(peer)


@rpc("authority", "call_local", "reliable")
func _revive(peer: int) -> void:
	coop_message.emit("Joueuse %d à terre — %d s pour la relever !" % [peer, int(DOWNED_WINDOW)])


func _tick_down(delta: float) -> void:
	if downed.is_empty():
		return
	var expired: Array = []
	for peer in downed.keys():
		downed[peer] = float(downed[peer]) - delta
		if float(downed[peer]) <= 0.0:
			expired.append(peer)
	for peer in expired:
		downed.erase(peer)
		level.call("_fail", "réanimation")
		return
	# L'autre joueuse maintient « Interaction » à portée : 2 s et c'est reparti.
	revive_hold = 0.0
	for peer in downed.keys():
		var helper := _other_player(peer)
		var target := players_by_peer.get(peer) as Player3D
		if helper == null or target == null:
			continue
		if not helper.interact_held:
			continue
		if helper.global_position.distance_to(target.global_position) > REVIVE_RANGE:
			continue
		revive_hold += delta
		if revive_hold >= REVIVE_HOLD:
			_do_revive(peer, target)
			return


func _other_player(exclude_peer: int) -> Player3D:
	for peer in players_by_peer.keys():
		if int(peer) != exclude_peer:
			return players_by_peer[peer] as Player3D
	return null


## Progression de la réanimation (0-1), lue par le HUD.
func revive_ratio() -> float:
	return clampf(revive_hold / REVIVE_HOLD, 0.0, 1.0)


func downed_peers() -> Array:
	return downed.keys()


## Une coéquipière est-elle à terre à portée ? (§ 22.3 : « Interaction » sert
## alors à la relever).
func downed_near(helper: Player3D) -> bool:
	if downed.is_empty() or helper == null:
		return false
	for peer in downed.keys():
		var target := players_by_peer.get(peer) as Player3D
		if target == null or not is_instance_valid(target):
			continue
		if helper.global_position.distance_to(target.global_position) <= REVIVE_RANGE:
			return true
	return false


func _do_revive(peer: int, player: Player3D) -> void:
	downed.erase(peer)
	revive_hold = 0.0
	player.call("revive_at", player.balance.max_health * REVIVE_HEALTH_RATIO)
	_revived.rpc(peer)


@rpc("authority", "call_local", "reliable")
func _revived(peer: int) -> void:
	coop_message.emit("Joueuse %d relevée." % peer)


## § 22.3 : déconnexion claire, on peut continuer en solo.
func _on_peer_left(id: int) -> void:
	var left := players_by_peer.get(id) as Player3D
	if left != null and is_instance_valid(left):
		left.queue_free()
	players_by_peer.erase(id)
	downed.erase(id)
	remote_player_left.emit(id)
	coop_message.emit("Joueuse %d a quitté la partie — tu continues en solo." % id)
	if is_host:
		Network.peer_ids.erase(id)


func other_players() -> Array:
	var out: Array = []
	for peer in players_by_peer.keys():
		if int(peer) == local_peer():
			continue
		out.append(players_by_peer[peer])
	return out
