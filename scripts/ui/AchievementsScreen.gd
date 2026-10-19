extends Control
class_name AchievementsScreen
## Écran des succès (PHASE 8). Construit par le code à partir des fiches
## `data/achievements/*.tres` : aucun texte n'est écrit ici. Les succès cachés
## restent « ??? » tant qu'ils ne sont pas débloqués.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const DIM: Color = Color(0.55, 0.52, 0.48)

var _list_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.078, 0.067)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.anchor_left = 0.5
	layout.anchor_right = 0.5
	layout.anchor_top = 0.0
	layout.anchor_bottom = 1.0
	layout.offset_left = -400.0
	layout.offset_right = 400.0
	layout.offset_top = 10.0
	layout.offset_bottom = -10.0
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)

	var title := Label.new()
	title.name = "Title"
	title.text = "SUCCÈS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var count := Label.new()
	count.name = "Count"
	count.text = "%d / %d" % [Achievements.unlocked_count(), Achievements.all().size()]
	count.add_theme_font_size_override("font_size", 22)
	count.add_theme_color_override("font_color", TEXT)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.name = "Rows"
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_box)

	var cards := Achievements.all()
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "Aucun succès pour le moment : joue un niveau !"
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", DIM)
		_list_box.add_child(empty)
	for card in cards:
		_list_box.add_child(_card_row(card))

	var back := Button.new()
	back.name = "Back"
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0.0, 54.0)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back)
	layout.add_child(back)


## Une ligne : titre, description, et avancement (« 7 / 20 » ou « ★ »).
func _card_row(card: AchievementData) -> PanelContainer:
	var unlocked := Achievements.is_unlocked(card.id)
	var current := Achievements.stat(card.stat)
	var panel := PanelContainer.new()
	panel.name = card.id
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.09, 0.95) if unlocked else Color(0.09, 0.08, 0.07, 0.9)
	style.border_color = Color(GOLD, 0.85) if unlocked else Color(0.3, 0.28, 0.26)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "???" if (card.hidden and not unlocked) else card.title
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD if unlocked else TEXT)
	column.add_child(title)

	var description := Label.new()
	description.name = "Description"
	description.text = "" if (card.hidden and not unlocked) else card.description
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", DIM if not unlocked else Color(TEXT, 0.85))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)

	var gauge := ProgressBar.new()
	gauge.name = "Progress"
	gauge.custom_minimum_size = Vector2(200.0, 18.0)
	gauge.max_value = float(card.target)
	gauge.value = float(mini(current, card.target))
	gauge.show_percentage = false
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gauge)

	var progress := Label.new()
	progress.name = "ProgressText"
	progress.text = "★" if unlocked else "%d / %d" % [mini(current, card.target), card.target]
	progress.add_theme_font_size_override("font_size", 16)
	progress.add_theme_color_override("font_color", GOLD if unlocked else DIM)
	progress.custom_minimum_size = Vector2(70.0, 0.0)
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(progress)
	return panel


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
