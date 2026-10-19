extends Control
class_name Shop
## Armurerie (§ 14.4 et § 16, PHASE 5) : trois améliorations permanentes
## achetées avec les cauris — Vitalité, Force, Souffle — et un aperçu chiffré
## de la joueuse. Les armes et l'arbre de compétences complets arrivent plus
## tard ; ces trois-là ferment déjà la boucle Résultat → Boutique → Carte.
##
## Tout est lu et écrit dans `SaveManager` : quitter et relancer conserve les
## achats.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const DANGER: Color = Color(1.0, 0.45, 0.4)

var buy_buttons: Dictionary = {}
var level_labels: Dictionary = {}
var price_labels: Dictionary = {}
var cauris_label: Label
var preview_label: Label
var feedback_label: Label

var _balance: Balance = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_balance = load("res://data/balance.tres") as Balance
	_build()
	refresh()


func _build() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.078, 0.067)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := VBoxContainer.new()
	column.name = "Layout"
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 48.0
	column.offset_top = 20.0
	column.offset_right = -48.0
	column.offset_bottom = -20.0
	column.add_theme_constant_override("separation", 14)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)

	var title := Label.new()
	title.text = "ARMURERIE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	cauris_label = Label.new()
	cauris_label.name = "Cauris"
	cauris_label.add_theme_font_size_override("font_size", 24)
	cauris_label.add_theme_color_override("font_color", GOLD)
	header.add_child(cauris_label)

	var hint := Label.new()
	hint.text = "Améliorations permanentes : elles s'appliquent à chaque niveau."
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(TEXT, 0.75))
	column.add_child(hint)

	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.13, 0.9)
	style.border_color = Color(GOLD, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", style)
	column.add_child(card)

	var rows := VBoxContainer.new()
	rows.name = "Upgrades"
	rows.add_theme_constant_override("separation", 16)
	card.add_child(rows)

	for id in SaveManager.UPGRADES.keys():
		rows.add_child(_make_upgrade_row(String(id)))

	preview_label = Label.new()
	preview_label.name = "Preview"
	preview_label.add_theme_font_size_override("font_size", 19)
	preview_label.add_theme_color_override("font_color", TEXT)
	column.add_child(preview_label)

	feedback_label = Label.new()
	feedback_label.name = "Feedback"
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.add_theme_color_override("font_color", GOLD)
	column.add_child(feedback_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	var back := Button.new()
	back.name = "Back"
	back.text = "Retour au menu"
	back.custom_minimum_size = Vector2(260.0, 54.0)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back)
	footer.add_child(back)
	column.add_child(footer)


func _make_upgrade_row(id: String) -> HBoxContainer:
	var info: Dictionary = SaveManager.UPGRADES[id]
	var row := HBoxContainer.new()
	row.name = id
	row.add_theme_constant_override("separation", 18)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = String(info["name"])
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", TEXT)
	text.add_child(name_label)

	var description := Label.new()
	description.text = String(info["description"])
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(TEXT, 0.7))
	text.add_child(description)

	var level_label := Label.new()
	level_label.add_theme_font_size_override("font_size", 18)
	level_label.add_theme_color_override("font_color", GOLD)
	text.add_child(level_label)
	level_labels[id] = level_label
	row.add_child(text)

	var price := Label.new()
	price.custom_minimum_size = Vector2(150.0, 0.0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 20)
	price.add_theme_color_override("font_color", GOLD)
	row.add_child(price)
	price_labels[id] = price

	var button := Button.new()
	button.name = "Buy"
	button.text = "Acheter"
	button.custom_minimum_size = Vector2(150.0, 56.0)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(buy.bind(id))
	row.add_child(button)
	buy_buttons[id] = button
	return row


## Met à jour cauris, niveaux, prix et boutons. Appelée à l'ouverture et après
## chaque achat.
func refresh() -> void:
	var cauris := int(SaveManager.data["cauris"])
	cauris_label.text = "CAURIS %d" % cauris
	for id in SaveManager.UPGRADES.keys():
		var info: Dictionary = SaveManager.UPGRADES[id]
		var level := SaveManager.upgrade_level(String(id))
		var maximum := int(info["max"])
		var cost := SaveManager.upgrade_cost(String(id))
		(level_labels[id] as Label).text = "Niveau %d / %d  %s" % [
			level, maximum, "●".repeat(level) + "○".repeat(maximum - level),
		]
		var price := price_labels[id] as Label
		var button := buy_buttons[id] as Button
		if cost < 0:
			price.text = "MAX"
			price.add_theme_color_override("font_color", TEXT)
			button.disabled = true
			button.text = "MAX"
		else:
			price.text = "%d cauris" % cost
			price.add_theme_color_override("font_color", GOLD if cauris >= cost else DANGER)
			button.disabled = cauris < cost
			button.text = "Acheter"
	preview_label.text = _preview_text()


func _preview_text() -> String:
	var base_health := _balance.max_health if _balance != null else 100.0
	var base_damage := _balance.base_damage if _balance != null else 10.0
	var health := base_health + SaveManager.upgrade_bonus("vitalite")
	var multiplier := SaveManager.damage_multiplier()
	var energy := SaveManager.upgrade_bonus("souffle")
	return "APERÇU  ·  Vie max %d (base %d)  ·  Dégâts %.1f × %.2f  ·  Énergie au départ %d" % [
		roundi(health), roundi(base_health), base_damage * multiplier, multiplier,
		roundi(energy),
	]


## Achat réel (les tests l'appellent directement, sans souris).
func buy(id: String) -> void:
	var before := SaveManager.upgrade_level(id)
	if not SaveManager.buy_upgrade(id):
		var cost := SaveManager.upgrade_cost(id)
		if cost > 0 and int(SaveManager.data["cauris"]) < cost:
			feedback_label.text = "Pas assez de cauris (il en manque %d)." % [
				cost - int(SaveManager.data["cauris"])
			]
			feedback_label.add_theme_color_override("font_color", DANGER)
		else:
			feedback_label.text = "Cette amélioration est déjà au maximum."
			feedback_label.add_theme_color_override("font_color", TEXT)
		refresh()
		return
	feedback_label.text = "%s améliorée — niveau %d !" % [
		SaveManager.UPGRADES[id]["name"], before + 1,
	]
	feedback_label.add_theme_color_override("font_color", GOLD)
	refresh()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
