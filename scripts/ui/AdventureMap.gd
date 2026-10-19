extends Control
class_name AdventureMap
## Carte du royaume (§ 16, PHASE 5) : les 5 chapitres et leurs 25 niveaux,
## avec étoiles, verrous et panneau « avant-niveau » (objectif, ennemis,
## récompense). Les fiches viennent de `data/levels/adventure/` : ajouter un
## `.tres` l'ajoute à la carte, sans toucher au code.
##
## Déblocage séquentiel : le niveau 1 est ouvert, chaque suivant demande au
## moins une étoile sur le précédent (la fin du chapitre 1 ouvre donc le 2).

const LEVEL_DIR: String = "res://data/levels/adventure"
const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const LOCKED: Color = Color(0.55, 0.52, 0.48)
const CHAPTER_TITLES: Array[String] = [
	"Les collines d'Abomey",
	"La route du sel",
	"La forêt sacrée",
	"Les remparts de nuit",
	"Le palais du roi",
]

var levels: Array[LevelData] = []
var level_buttons: Dictionary = {}
var selected: LevelData = null

var info_label: Label
var play_button: Button
var panel: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	levels = _load_levels()
	_build()
	_refresh()


func _load_levels() -> Array[LevelData]:
	var found: Array[LevelData] = []
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		push_warning("AdventureMap : dossier %s introuvable" % LEVEL_DIR)
		return found
	# Dans un export (APK), un `.tres` devient `.tres.remap` : la liste ne
	# contient donc plus les noms d'origine. On enlève le suffixe et `load()`
	# retrouve la ressource par son remap.
	for file_name in dir.get_files():
		var resource_name := String(file_name).trim_suffix(".remap")
		if not resource_name.ends_with(".tres"):
			continue
		var data := load("%s/%s" % [LEVEL_DIR, resource_name]) as LevelData
		if data != null:
			found.append(data)
	found.sort_custom(func(a: LevelData, b: LevelData) -> bool:
		if a.chapter != b.chapter:
			return a.chapter < b.chapter
		return a.number < b.number
	)
	return found


func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.078, 0.067)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.name = "Layout"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 32.0
	column.offset_top = 16.0
	column.offset_right = -32.0
	column.offset_bottom = -16.0
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	var header := HBoxContainer.new()
	header.name = "Header"
	column.add_child(header)

	var title := Label.new()
	title.text = "CARTE DU ROYAUME"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var cauris := Label.new()
	cauris.name = "Cauris"
	cauris.text = "CAURIS %d" % int(SaveManager.data["cauris"])
	cauris.add_theme_font_size_override("font_size", 22)
	cauris.add_theme_color_override("font_color", GOLD)
	header.add_child(cauris)

	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	var chapters := VBoxContainer.new()
	chapters.name = "Chapters"
	chapters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapters.add_theme_constant_override("separation", 14)
	scroll.add_child(chapters)

	var current_chapter := -1
	var row: HBoxContainer = null
	for data in levels:
		if data.chapter != current_chapter:
			current_chapter = data.chapter
			var chapter_title := "Chapitre %d" % current_chapter
			if current_chapter <= CHAPTER_TITLES.size():
				chapter_title = CHAPTER_TITLES[current_chapter - 1]
			var caption := Label.new()
			caption.text = "CHAPITRE %d — %s" % [current_chapter, chapter_title]
			caption.add_theme_font_size_override("font_size", 20)
			caption.add_theme_color_override("font_color", Color(TEXT, 0.85))
			chapters.add_child(caption)
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			chapters.add_child(row)
		row.add_child(_make_level_button(data))

	_build_panel(body)
	column.add_child(_build_footer())


func _make_level_button(data: LevelData) -> Button:
	var button := Button.new()
	button.name = data.id
	button.custom_minimum_size = Vector2(104.0, 88.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(select_level.bind(data.id))
	level_buttons[data.id] = button
	button.tooltip_text = data.display_name
	return button


func _build_panel(parent: HBoxContainer) -> void:
	panel = VBoxContainer.new()
	panel.name = "BeforeLevel"
	panel.custom_minimum_size = Vector2(380.0, 0.0)
	panel.add_theme_constant_override("separation", 12)
	parent.add_child(panel)

	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.13, 0.92)
	style.border_color = Color(GOLD, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	panel.add_child(card)

	info_label = Label.new()
	info_label.name = "Info"
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", TEXT)
	info_label.text = "Choisis un niveau sur la carte."
	card.add_child(info_label)

	play_button = Button.new()
	play_button.name = "Play"
	play_button.text = "JOUER"
	play_button.custom_minimum_size = Vector2(0.0, 62.0)
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.add_theme_color_override("font_color", GOLD)
	play_button.disabled = true
	play_button.pressed.connect(play)
	panel.add_child(play_button)


func _build_footer() -> HBoxContainer:
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.name = "Back"
	back.text = "Modes"
	back.custom_minimum_size = Vector2(220.0, 52.0)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back)
	footer.add_child(back)
	return footer


## Étoiles déjà gagnées (0 à 3), lues dans la sauvegarde.
func stars_of(data: LevelData) -> int:
	return SaveManager.stars_for(data.id)


## Un niveau est ouvert si c'est le premier ou si le précédent a ≥ 1 étoile.
func can_play(id: String) -> bool:
	var index := -1
	for i in levels.size():
		if levels[i].id == id:
			index = i
			break
	if index < 0:
		return false
	if index == 0:
		return true
	return stars_of(levels[index - 1]) > 0


## Met à jour les boutons (étoiles, verrous) après un achat ou un retour.
func _refresh() -> void:
	for data in levels:
		var button := level_buttons.get(data.id) as Button
		if button == null:
			continue
		var stars := stars_of(data)
		var opened := can_play(data.id)
		button.disabled = not opened
		button.text = "%d\n%s" % [
			data.number,
			("★".repeat(stars) + "☆".repeat(3 - stars)) if opened else "verrouillé",
		]
		button.add_theme_color_override("font_color", TEXT if opened else LOCKED)
		button.modulate = Color.WHITE if opened else Color(1, 1, 1, 0.65)
	if selected != null:
		_show_info(selected)


func select_level(id: String) -> void:
	for data in levels:
		if data.id == id:
			if not can_play(id):
				return
			selected = data
			_show_info(data)
			return


func _show_info(data: LevelData) -> void:
	var stars := stars_of(data)
	var objective: String = String({
		"clear": "Vaincre toutes les vagues",
		"survive": "Tenir jusqu'à la fin du temps",
		"exit": "Atteindre la sortie",
		"boss": "Vaincre le gardien",
		"rescue": "Libérer les prisonniers",
		"escort": "Escorter le villageois",
	}.get(data.objective, data.objective))
	var layout := "Couloir · %.0f m" % data.length_m if data.is_lane() \
		else "Arène · rayon %.0f m" % data.arena_radius
	info_label.text = "%s\n\n%s\n%s\n\nObjectif : %s\nEnnemis : %d en %d vague(s)\nTemps : %d s\nRécompense : %d cauris\nRecord : %s" % [
		data.display_name, "CHAPITRE %d — NIVEAU %d" % [data.chapter, data.number],
		layout, objective, data.enemy_total(), data.enemy_waves.size(),
		data.time_limit, data.reward_cauris,
		("★".repeat(stars) + "☆".repeat(3 - stars)) if stars > 0 else "aucun",
	]
	play_button.disabled = false


func play() -> void:
	if selected == null or not can_play(selected.id):
		return
	GameState.mode = GameState.GameMode.ADVENTURE
	GameState.current_level_data = selected
	get_tree().change_scene_to_file("res://scenes/levels/LevelBase3D.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
