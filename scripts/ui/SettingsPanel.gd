extends Control
class_name SettingsPanel
## Réglages du § 16 : difficulté, langue, volumes, taille des boutons,
## vibration, qualité graphique, échelle 3D. Construit par le code (aucune
## texture) et utilisable depuis le menu principal comme depuis la pause.
##
## Chaque changement s'applique IMMÉDIATEMENT et est écrit dans
## `SaveManager.data["settings"]` : fermer le jeu ne perd rien.

signal closed

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const DIM: Color = Color(0.04, 0.05, 0.09, 0.82)
const CARD: Color = Color(0.10, 0.08, 0.07, 0.98)

var _dims: ColorRect
var _card: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	_dims = ColorRect.new()
	_dims.name = "Dim"
	_dims.color = DIM
	_dims.mouse_filter = Control.MOUSE_FILTER_STOP
	_dims.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dims)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size = Vector2(700.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = Color(GOLD, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)

	var column := VBoxContainer.new()
	column.name = "Rows"
	column.add_theme_constant_override("separation", 14)
	_card.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "RÉGLAGES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	_add_volume_row(column, "Musique", Settings.music_volume, Settings.set_music_volume)
	_add_volume_row(column, "Effets", Settings.sfx_volume, Settings.set_sfx_volume)
	_add_volume_row(column, "Voix", Settings.voice_volume, Settings.set_voice_volume)

	_add_slider_row(column, "Taille des boutons", 0.8, 1.3, 0.05,
		Settings.button_scale, Settings.set_button_scale, "×%.2f")
	_add_slider_row(column, "Opacité des boutons", 0.2, 1.0, 0.05,
		Settings.button_opacity, Settings.set_button_opacity, "%.0f %%", 100.0)
	_add_slider_row(column, "Échelle 3D", 0.6, 1.0, 0.05,
		Settings.scale_3d, Settings.set_scale_3d, "%.2f")

	var difficulty := _add_options_row(column, "Difficulté",
		["Facile", "Normal", "Difficile"], ["easy", "normal", "hard"],
		Settings.difficulty)
	difficulty.item_selected.connect(func(index: int) -> void:
		Settings.set_difficulty(difficulty.get_item_metadata(index))
	)

	# ANNEXE §7 : palier de difficulté par partie (le mode historique reste
	# disponible au-dessus pour les sauvegardes existantes).
	var tier := _add_options_row(column, "Palier de défi",
		["Aucun (historique)", "Récit", "Guerrière", "Légende", "Éternelle"],
		["", "recit", "guerriere", "legende", "eternelle"], Settings.tier)
	tier.item_selected.connect(func(index: int) -> void:
		Settings.set_tier(tier.get_item_metadata(index))
	)

	var quality := _add_options_row(column, "Qualité graphique",
		["Faible", "Moyenne", "Haute"], ["low", "medium", "high"],
		Settings.quality)
	quality.item_selected.connect(func(index: int) -> void:
		Settings.set_quality(quality.get_item_metadata(index))
	)

	var language := _add_options_row(column, "Langue",
		["Français", "English", "Fon"], ["fr", "en", "fon"],
		Settings.language)
	language.item_selected.connect(func(index: int) -> void:
		Settings.set_language(language.get_item_metadata(index))
	)

	var vibration := CheckButton.new()
	vibration.name = "Vibration"
	vibration.text = "Vibration"
	vibration.button_pressed = Settings.vibration
	vibration.toggled.connect(func(pressed: bool) -> void: Settings.set_vibration(pressed))
	column.add_child(_row("Vibration", vibration))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	column.add_child(spacer)

	var back := Button.new()
	back.name = "Back"
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0.0, 56.0)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_on_close)
	column.add_child(back)


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(300.0, 0.0)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", TEXT)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_volume_row(parent: VBoxContainer, label_text: String,
		value: float, setter: Callable) -> void:
	var slider := HSlider.new()
	slider.name = label_text
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(340.0, 32.0)
	slider.value_changed.connect(func(v: float) -> void: setter.call(v))
	parent.add_child(_row(label_text, slider))


func _add_slider_row(parent: VBoxContainer, label_text: String,
		minimum: float, maximum: float, step: float, value: float,
		setter: Callable, format: String, display_scale: float = 1.0) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.name = label_text
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(300.0, 32.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(88.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_size_override("font_size", 18)
	readout.add_theme_color_override("font_color", TEXT)
	readout.text = format % (value * display_scale)
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = format % (v * display_scale)
		setter.call(v)
	)
	box.add_child(slider)
	box.add_child(readout)
	parent.add_child(_row(label_text, box))


## OptionButton dont la valeur réelle est dans les métadonnées (String).
func _add_options_row(parent: VBoxContainer, label_text: String,
		labels: Array, values: Array, current: String) -> OptionButton:
	var options := OptionButton.new()
	options.name = label_text
	options.custom_minimum_size = Vector2(340.0, 40.0)
	for i in labels.size():
		options.add_item(String(labels[i]), i)
		options.set_item_metadata(i, String(values[i]))
		if String(values[i]) == current:
			options.select(i)
	parent.add_child(_row(label_text, options))
	return options


func _on_close() -> void:
	closed.emit()
	queue_free()
