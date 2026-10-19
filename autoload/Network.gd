extends Node
## Réseau coop WiFi local (DOSSIER.md § 22) : hôte autoritaire ENet/UDP port 7777,
## découverte LAN par broadcast UDP port 7778 + IP manuelle en secours.
##
## PHASE 7 : le Lobby (hôte/invité), le lancement du niveau chez les deux
## joueuses, la difficulté coop (§ 22.3) et la déconnexion vivent ici. La
## synchronisation des entités se fait dans le niveau (`MultiplayerSpawner` +
## `MultiplayerSynchronizer`), pas dans cet autoload.
##
## Règle du § 22.1 : **l'hôte simule** (ennemis, dégâts, objectifs, timer) ; le
## client envoie ses inputs et reçoit l'état. `Authority` ci-dessous résume
## cette règle pour tout le jeu : les scripts ne testent jamais le mode en dur.

const GAME_PORT: int = 7777
const DISCOVERY_PORT: int = 7778
const MAX_CLIENTS: int = 1                 ## § 22 : 2 joueuses au total
const GAME_ID: String = "GUERRIERE_ABOMEY_3D_v1"
const REFRESH_MS: int = 5000               ## une partie vue est valable 5 s

signal peer_joined(id: int)
signal peer_left(id: int)
signal hosts_found(list: Array)
signal connection_failed
## § 22.3 : messages du lobby (erreurs, déconnexion) que l'écran affiche tel quel.
signal lobby_message(text: String)
## Le niveau coop démarre chez les deux joueuses avec cette fiche.
signal coop_started(level_path: String)

var udp_broadcaster: PacketPeerUDP = null
var udp_listener: PacketPeerUDP = null
var broadcast_timer: Timer = null
var discovered: Dictionary = {}          ## { ip: {name, time} }
var host_name: String = "Nawi"
var is_hosting: bool = false
var peer_ids: Array[int] = []            ## pairs connectés (hors nous)


# -----------------------------------------------------------------#
#                          ÉTAT                                       #
# -----------------------------------------------------------------#

## Une partie en réseau est-elle en cours ? (hôte ou invité connecté)
##
## Attention : Godot installe un `OfflineMultiplayerPeer` (lui aussi « connecté »)
## quand aucun pair n'est ouvert — sans ce test, tout le jeu croirait être en
## coop en solo.
func is_coop() -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## Y a-t-il un pair réseau, même pas encore connecté ? (lobby en cours)
func is_online() -> bool:
	return multiplayer.multiplayer_peer != null


## L'hôte simule : § 22.1, règle unique pour tout le gameplay.
func is_host() -> bool:
	return multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id()


## Identifiants de toutes les joueuses, hôte inclus (ordre stable).
func coop_player_ids() -> Array[int]:
	var out: Array[int] = [1]
	for id in peer_ids:
		if id != 1 and not out.has(id):
			out.append(id)
	return out


## § 22.3 : « vie ennemis ×1,5 » (GameState.coop_health_mult), « nombre ×1,3 »,
## « max 6 à l'écran ».
func coop_count_mult() -> float:
	return 1.3 if is_coop() else 1.0


func coop_max_on_screen() -> int:
	return 6 if is_coop() else 5


# -----------------------------------------------------------------#
#                        CONNEXION                                   #
# -----------------------------------------------------------------#

func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(GAME_PORT, MAX_CLIENTS) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	is_hosting = true
	peer_ids.clear()
	_start_broadcast()
	lobby_message.emit("En attente d'une joueuse… IP : %s" % get_local_ip())


func join_game(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if ip.strip_edges().is_empty() or peer.create_client(ip.strip_edges(), GAME_PORT) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	_connect_signals()
	_stop_listening()
	lobby_message.emit("Connexion à %s…" % ip)


func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func leave() -> void:
	_stop_broadcast()
	_stop_listening()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_hosting = false
	peer_ids.clear()
	discovered.clear()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_connected_to_server() -> void:
	var id := multiplayer.get_unique_id()
	lobby_message.emit("Connectée (joueur %d)." % id)
	if not peer_ids.has(id):
		peer_ids.append(id)


## L'hôte a fermé la partie : on le dit clairement au lieu de rester figé.
func _on_server_disconnected() -> void:
	leave()
	lobby_message.emit("L'hôte a quitté la partie.")
	peer_left.emit(0)
	# § 22.3 : en pleine partie, on ne laisse pas l'invitée devant un niveau
	# figé — retour au menu, où elle peut relancer une coop ou jouer en solo.
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("fail_offline"):
		scene.call("fail_offline", "L'hôte a quitté la partie.")


# -----------------------------------------------------------------#
#                     LANCEMENT DU NIVEAU                            #
# -----------------------------------------------------------------#

## L'hôte lance le niveau chez tout le monde (§ 22.1 : l'hôte décide).
func launch_coop_level(level_path: String) -> void:
	if not is_host():
		lobby_message.emit("Seul l'hôte lance la partie.")
		return
	rpc("_launch_level_rpc", level_path)


## Applique la même fiche de niveau des deux côtés : les niveaux étant
## reproductibles (`_rng.seed = hash(id)`), chaque machine construit le MÊME
## décor sans rien transmettre.
@rpc("authority", "call_local", "reliable")
func _launch_level_rpc(level_path: String) -> void:
	var data := load(level_path) as LevelData
	if data == null:
		lobby_message.emit("Niveau introuvable : %s" % level_path)
		return
	GameState.mode = GameState.GameMode.COOP
	GameState.current_level_data = data
	coop_started.emit(level_path)
	get_tree().change_scene_to_file("res://scenes/levels/LevelBase3D.tscn")


# -----------------------------------------------------------------#
#                    DÉGÂTS DE L'INVITÉE (§ 22.1)                    #
# -----------------------------------------------------------------#

## L'invitée n'applique aucun dégât : elle envoie ses coups à l'hôte, qui est
## seul maître de la vie des ennemis. `hurtbox_path` est un chemin absolu, valable
## chez les deux joueuses (les deux arbres portent les mêmes noms de nœuds).
@rpc("any_peer", "call_remote", "reliable")
func request_hit(hurtbox_path: NodePath, amount: float, knockback: float,
		heavy: bool, critical: bool) -> void:
	if not is_host():
		return
	var hurtbox := get_tree().root.get_node_or_null(hurtbox_path) as Hurtbox3D
	if hurtbox == null or hurtbox.owner_actor == null:
		return
	var info := DamageInfo.new()
	info.amount = amount
	info.knockback = knockback
	info.source_actor = null
	info.source_position = hurtbox.global_position
	info.is_heavy = heavy
	info.is_critical = critical
	hurtbox.receive_hit(info)


## Rejouer le niveau coop (§ 22.3) : l'hôte décide, les deux rechargent la
## scène. La connexion ENet survit au changement de scène (elle vit dans
## l'autoload), seuls les nœuds du niveau disparaissent.
func restart_coop_level() -> void:
	if is_host():
		_reload_scene.rpc()


@rpc("authority", "call_local", "reliable")
func _reload_scene() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# -----------------------------------------------------------------#
#                        DÉCOUVERTE LAN                              #
# -----------------------------------------------------------------#

func _start_broadcast() -> void:
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 1.0
	broadcast_timer.timeout.connect(_send_announce)
	add_child(broadcast_timer)
	broadcast_timer.start()
	_send_announce()


func _send_announce() -> void:
	if udp_broadcaster == null:
		return
	var msg := JSON.stringify({"game": GAME_ID, "name": host_name, "port": GAME_PORT})
	udp_broadcaster.put_packet(msg.to_utf8_buffer())


func _stop_broadcast() -> void:
	if broadcast_timer:
		broadcast_timer.queue_free()
		broadcast_timer = null
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null


func start_listening() -> void:
	_stop_listening()
	udp_listener = PacketPeerUDP.new()
	udp_listener.bind(DISCOVERY_PORT)


func _stop_listening() -> void:
	if udp_listener:
		udp_listener.close()
		udp_listener = null


func _process(_delta: float) -> void:
	if udp_listener == null:
		return
	# Purge des parties vues il y a plus de 5 s (l'hôte a quitté).
	var now := Time.get_ticks_msec()
	var expired: Array = []
	for ip in discovered:
		if now - int(discovered[ip]["time"]) > REFRESH_MS:
			expired.append(ip)
	for ip in expired:
		discovered.erase(ip)
	if not expired.is_empty():
		hosts_found.emit(discovered.keys())
	# Écoute des annonces.
	while udp_listener.get_available_packet_count() > 0:
		var ip := udp_listener.get_packet_ip()
		var data = JSON.parse_string(udp_listener.get_packet().get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.get("game") == GAME_ID:
			discovered[ip] = {"name": str(data.get("name", "?")), "time": now}
			hosts_found.emit(discovered.keys())


func _on_peer_connected(id: int) -> void:
	if not peer_ids.has(id):
		peer_ids.append(id)
	lobby_message.emit("Joueuse %d connectée." % id)
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	peer_ids.erase(id)
	lobby_message.emit("Joueuse %d déconnectée." % id)
	peer_left.emit(id)


func get_local_ip() -> String:
	## Affichée en grand dans le Lobby (§ 22.3) pour le champ IP manuelle.
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "inconnue"
