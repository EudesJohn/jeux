extends Node
## Succès (PHASE 8). Deux idées simples :
##  - chaque succès est une **fiche** `data/achievements/*.tres` (compteur + seuil),
##    donc en ajouter un ne touche pas au code ;
##  - les compteurs vivent dans `SaveManager.data["stats"]` et progressent en
##    écoutant `Events` (aucun script de gameplay ne connaît les succès).
##
## Un succès débloqué est écrit dans `SaveManager.data["achievements"]` (liste
## d'identifiants) : il n'est jamais perdu, même si le compteur baisse.

signal unlocked(achievement: AchievementData)
signal stats_changed

const DIR := "res://data/achievements"
const TOAST_SECONDS := 3.0

## Ordre d'affichage de l'écran des succès.
var _list: Array[AchievementData] = []
var _queue: Array[AchievementData] = []

var _toast_layer: CanvasLayer = null
var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_cards()
	Events.enemy_died.connect(_on_enemy_died)
	Events.perfect_guard.connect(_on_perfect_guard)
	Events.prisoner_freed.connect(_on_prisoner_freed)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.level_completed.connect(_on_level_completed)


func _load_cards() -> void:
	_list.clear()
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("Achievements : dossier %s introuvable" % DIR)
		return
	var names := dir.get_files()
	names.sort()
	for file in names:
		# En export, les .tres deviennent des .remap.
		var path := DIR + "/" + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var card := load(path) as AchievementData
		if card != null and not card.id.is_empty():
			_list.append(card)


## Toutes les fiches, dans l'ordre des fichiers.
func all() -> Array[AchievementData]:
	return _list


func find(id: String) -> AchievementData:
	for card in _list:
		if card.id == id:
			return card
	return null


# -----------------------------------------------------------------#
#                        COMPTEURS ET SEUILS                      #
# -----------------------------------------------------------------#

func stat(name: String) -> int:
	var stats: Dictionary = SaveManager.data.get("stats", {})
	return int(stats.get(name, 0))


## Ajoute `amount` à un compteur puis vérifie les succès concernés.
func report(name: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	_write_stat(name, stat(name) + amount)


## Fixe un compteur seulement s'il monte (records : vagues, série de jours).
func set_at_least(name: String, value: int) -> void:
	if value > stat(name):
		_write_stat(name, value)


func _write_stat(name: String, value: int) -> void:
	var stats: Dictionary = SaveManager.data.get("stats", {})
	stats[name] = value
	SaveManager.data["stats"] = stats
	_check_all()
	stats_changed.emit()


func is_unlocked(id: String) -> bool:
	var unlocked_list: Array = SaveManager.data.get("achievements", [])
	return unlocked_list.has(id)


## Nombre de succès débloqués / total (écran et tests).
func unlocked_count() -> int:
	var count := 0
	for card in _list:
		if is_unlocked(card.id):
			count += 1
	return count


func _check_all() -> void:
	for card in _list:
		if is_unlocked(card.id):
			continue
		if stat(card.stat) >= card.target:
			_unlock(card)


func _unlock(card: AchievementData) -> void:
	var unlocked_list: Array = SaveManager.data.get("achievements", [])
	unlocked_list.append(card.id)
	SaveManager.data["achievements"] = unlocked_list
	SaveManager.save_game()
	unlocked.emit(card)
	_queue_toast(card)


# -----------------------------------------------------------------#
#                       SIGNAUX DU GAMEPLAY                       #
# -----------------------------------------------------------------#

func _on_enemy_died(enemy: Node) -> void:
	# Un boss est compté par `boss_defeated` : pas de double comptage.
	if enemy is BossBase3D:
		return
	report("kills")


func _on_perfect_guard(_actor: Node) -> void:
	report("perfect_guards")


func _on_prisoner_freed(_prisoner: Node) -> void:
	report("rescued")


func _on_boss_defeated(_boss: Node) -> void:
	report("bosses")
	report("kills")


func _on_level_completed(_level_id: String, _stars: int) -> void:
	report("levels")
	if Network.is_coop() and multiplayer != null and multiplayer.is_server():
		report("coop_levels")


# -----------------------------------------------------------------#
#                    BANDEAU DE DÉBLOCAGE                          #
# -----------------------------------------------------------------#

## Petit bandeau en haut de l'écran, un à la fois (les suivants attendent).
func _queue_toast(card: AchievementData) -> void:
	_queue.append(card)
	if _queue.size() == 1:
		_show_next_toast()


func _ensure_toast() -> void:
	if _toast_layer != null and is_instance_valid(_toast_layer):
		return
	_toast_layer = CanvasLayer.new()
	_toast_layer.name = "AchievementToast"
	_toast_layer.layer = 90
	add_child(_toast_layer)

	_toast_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.06, 0.96)
	style.border_color = Color(0.89, 0.66, 0.17, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_top = 16.0
	_toast_panel.offset_left = -260.0
	_toast_panel.offset_right = 260.0
	_toast_panel.modulate.a = 0.0
	_toast_layer.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	_toast_panel.add_child(_toast_label)


func _show_next_toast() -> void:
	if _queue.is_empty():
		return
	var card: AchievementData = _queue[0]
	_ensure_toast()
	var title := tr(card.title)
	_toast_label.text = Localizer.format_tr("SUCCÈS : %s", [title])
	_toast_label.set_meta(&"i18n_source", "SUCCÈS : %s")
	_toast_label.set_meta(&"i18n_args", [title])

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_on_toast_done)


func _on_toast_done() -> void:
	if not _queue.is_empty():
		_queue.pop_front()
	if not _queue.is_empty():
		_show_next_toast()
