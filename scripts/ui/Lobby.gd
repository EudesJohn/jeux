extends Control
class_name Lobby
## Lobby coop (§ 22.3, PHASE 7). L'hôte voit **son adresse IP en grand** et
## attend ; l'invité voit les parties détectées par broadcast LAN **et** un champ
## d'IP manuelle obligatoire en secours (beaucoup de hotspots isolent les
## clients, le broadcast ne passe alors pas).
##
## L'écran ne fait qu'appeler `Network` : toute la logique réseau reste dans
## l'autoload (§ 18 règle 3), et `Network.launch_coop_level()` démarre le niveau
## chez les deux joueuses.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const BACKGROUND: Color = Color(0.10, 0.078, 0.067)
## Niveaux proposés en coop : un couloir (la caméra cadre les deux) et une arène.
const COOP_LEVELS: Array = [
	["Couloir coop", "res://data/levels/lane_02.tres"],
	["Arène coop", "res://data/levels/arena_01.tres"],
]

var status_label: Label
var ip_label: Label
var message_label: Label
var start_button: Button
var host_button: Button
var join_button: Button
var connect_button: Button
var ip_edit: LineEdit
var hosts_list: VBoxContainer
var level_button: Button
var level_choice: int = 0
var mode: String = ""                    ## "" | "host" | "join"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	Network.lobby_message.connect(_on_message)
	Network.hosts_found.connect(_on_hosts_found)
	Network.peer_joined.connect(_on_peer_joined)
	Network.peer_left.connect(_on_peer_left)
	Network.connection_failed.connect(_on_connection_failed)


func _exit_tree() -> void:
	# On ne laisse pas un écouteur UDP ouvert derrière soi.
	if mode == "join":
		Network._stop_listening()


# -----------------------------------------------------------------#
#                        INTERFACE                                  #
# -----------------------------------------------------------------#

func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = -420.0
	column.offset_right = 420.0
	column.offset_top = 8.0
	column.offset_bottom = -8.0
	add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "COOP WIFI — 2 JOUEUSES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	# --- Hôte ----------------------------------------------------
	host_button = _button("Héberger une partie", "Host")
	host_button.pressed.connect(_on_host)
	column.add_child(host_button)

	ip_label = Label.new()
	ip_label.name = "HostIp"
	ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_label.add_theme_font_size_override("font_size", 34)
	ip_label.add_theme_color_override("font_color", GOLD)
	column.add_child(ip_label)

	level_button = _button("Niveau : Couloir coop", "Level")
	level_button.pressed.connect(_on_cycle_level)
	column.add_child(level_button)

	start_button = _button("Commencer", "Start")
	start_button.disabled = true
	start_button.pressed.connect(_on_start)
	column.add_child(start_button)

	# --- Invité --------------------------------------------------
	join_button = _button("Rejoindre une partie", "Join")
	join_button.pressed.connect(_on_join)
	column.add_child(join_button)

	hosts_list = VBoxContainer.new()
	hosts_list.name = "Hosts"
	hosts_list.add_theme_constant_override("separation", 6)
	column.add_child(hosts_list)

	var manual := HBoxContainer.new()
	manual.name = "Manual"
	manual.add_theme_constant_override("separation", 8)
	column.add_child(manual)

	ip_edit = LineEdit.new()
	ip_edit.name = "IpEdit"
	ip_edit.placeholder_text = "IP de l'hôte (ex. 192.168.43.1)"
	ip_edit.custom_minimum_size = Vector2(0.0, 54.0)
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manual.add_child(ip_edit)

	connect_button = _button("Se connecter", "Connect")
	connect_button.pressed.connect(_on_connect_manual)
	manual.add_child(connect_button)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", TEXT)
	column.add_child(status_label)

	message_label = Label.new()
	message_label.name = "Message"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.5))
	column.add_child(message_label)

	var back := _button("Retour", "Back")
	back.pressed.connect(_on_back)
	column.add_child(back)

	_show_idle()


func _button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", TEXT)
	return button


## État de repos : on ne propose que les deux portes d'entrée.
func _show_idle() -> void:
	mode = ""
	ip_label.text = ""
	level_button.visible = false
	start_button.visible = false
	host_button.visible = true
	join_button.visible = true
	connect_button.visible = true
	ip_edit.visible = true
	hosts_list.visible = true
	status_label.text = "Un seul réseau WiFi : la box, ou le hotspot de l'un des deux téléphones."


# -----------------------------------------------------------------#
#                          ACTIONS                                  #
# -----------------------------------------------------------------#

func _on_host() -> void:
	mode = "host"
	Network.host_game()
	ip_label.text = Network.get_local_ip()
	host_button.visible = false
	join_button.visible = false
	connect_button.visible = false
	ip_edit.visible = false
	hosts_list.visible = false
	level_button.visible = true
	start_button.visible = true
	_refresh_level_button()
	status_label.text = "En attente d'une joueuse…"


func _on_join() -> void:
	mode = "join"
	Network.start_listening()
	host_button.visible = false
	join_button.visible = false
	level_button.visible = false
	start_button.visible = false
	status_label.text = "Recherche des parties sur le réseau… (ou tape l'IP de l'hôte)"
	_on_hosts_found(Network.discovered.keys())


func _on_connect_manual() -> void:
	Network.join_game(ip_edit.text)


func _on_start() -> void:
	var path := String(COOP_LEVELS[level_choice][1])
	Network.launch_coop_level(path)


func _on_cycle_level() -> void:
	level_choice = (level_choice + 1) % COOP_LEVELS.size()
	_refresh_level_button()


func _refresh_level_button() -> void:
	level_button.text = "Niveau : %s" % String(COOP_LEVELS[level_choice][0])


func _on_back() -> void:
	Network.leave()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


# -----------------------------------------------------------------#
#                       RÉPONSES RÉSEAU                             #
# -----------------------------------------------------------------#

## Parties détectées : un bouton par hôte trouvé (nom + IP).
func _on_hosts_found(list: Array) -> void:
	for child in hosts_list.get_children():
		child.queue_free()
	for ip in list:
		var info: Dictionary = Network.discovered.get(ip, {})
		var button := _button("%s — %s" % [String(info.get("name", "?")), String(ip)],
			"Host_%s" % String(ip).replace(".", "_"))
		button.pressed.connect(func() -> void: Network.join_game(String(ip)))
		hosts_list.add_child(button)
	if list.is_empty() and mode == "join":
		status_label.text = "Aucune partie détectée. Tape l'IP affichée sur l'autre téléphone."


func _on_peer_joined(id: int) -> void:
	if mode != "host":
		return
	status_label.text = "Joueuse %d connectée — prêt." % id
	start_button.disabled = false


func _on_peer_left(_id: int) -> void:
	if mode != "host":
		return
	status_label.text = "La joueuse est partie. En attente…"
	start_button.disabled = true


func _on_connection_failed() -> void:
	message_label.text = ("Connexion impossible. Vérifie que les deux téléphones sont sur le "
		+ "MÊME réseau (le plus simple : le hotspot d'un des deux) et que l'IP est bonne.")


func _on_message(text: String) -> void:
	message_label.text = text
	if mode == "join" and text.begins_with("Connectée"):
		status_label.text = text
