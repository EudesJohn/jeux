extends CanvasLayer
class_name ResultScreen
## Écran de fin de niveau (§ 13 et § 16, PHASE 4) : « NIVEAU TERMINÉ » avec les
## étoiles, le temps restant et les cauris, ou « ÉCHEC » avec la raison.
## Deux boutons : REJOUER (le niveau repart à zéro) et MENU.
##
## Construit par le code : le niveau en a toujours un, sans scène à charger.
## Le niveau écoute `replay_pressed` / `menu_pressed` (§ 18 règle 3).

const OVERLAY_COLOR: Color = Color(0.04, 0.05, 0.09, 0.72)
const GOLD: Color = Color(0.89, 0.66, 0.17)
const DANGER: Color = Color(1.0, 0.45, 0.4)
const TEXT: Color = Color(0.96, 0.91, 0.82)

const REASONS: Dictionary = {
	"vie": "tu es tombée au combat",
	"temps": "temps écoulé",
	"prisonnier": "un prisonnier est mort",
	"villageois": "le villageois est mort",
	"objectif": "objectif manqué",
}

signal replay_pressed
signal menu_pressed

var shown: bool = false
var victory: bool = false
var stars: int = 0

var view: Control
var title_label: Label
var detail_label: Label
var replay_button: Button
var menu_button: Button


func _ready() -> void:
	layer = 2
	_build()
	hide_screen()


func _build() -> void:
	view = Control.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = OVERLAY_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	view.add_child(dim)

	var panel := VBoxContainer.new()
	panel.name = "Panel"
	# Centré sur la largeur réelle : un téléphone en 2:1 fait 1612 px de large.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(660.0, 300.0)
	panel.offset_left = -330.0
	panel.offset_right = 330.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	panel.add_theme_constant_override("separation", 18)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	view.add_child(panel)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 52)
	title_label.text = ""
	panel.add_child(title_label)

	detail_label = Label.new()
	detail_label.name = "Detail"
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 24)
	detail_label.add_theme_color_override("font_color", TEXT)
	detail_label.text = ""
	panel.add_child(detail_label)

	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	replay_button = _button("REJOUER", "Replay")
	replay_button.pressed.connect(_on_replay)
	row.add_child(replay_button)

	menu_button = _button("CONTINUER", "Menu")
	menu_button.pressed.connect(_on_menu)
	row.add_child(menu_button)


func _button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(220.0, 62.0)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", TEXT)
	return button


## Victoire : étoiles, temps restant et cauris gagnés.
func show_win(earned: int, time_left: float, cauris: int) -> void:
	victory = true
	stars = clampi(earned, 0, 3)
	Localizer.set_text(title_label, "NIVEAU TERMINÉ")
	title_label.add_theme_color_override("font_color", GOLD)
	var star_text := "★".repeat(stars) + "☆".repeat(3 - stars)
	Localizer.set_text(detail_label, "%s      %s restantes      +%d cauris    ", [
		star_text, _format_time(time_left), cauris])
	_show()


## Défaite : la raison (§ 13 : vie, temps, prisonnier, villageois…).
func show_defeat(reason: String) -> void:
	victory = false
	stars = 0
	Localizer.set_text(title_label, "ÉCHEC")
	title_label.add_theme_color_override("font_color", DANGER)
	var label := Localizer.format_tr(String(REASONS.get(reason, reason)))
	Localizer.set_text(detail_label, "— %s —", [label])
	_show()


func _show() -> void:
	shown = true
	view.visible = true
	# § 16 : après un niveau de campagne, le bouton ramène à la carte.
	Localizer.set_text(menu_button, "CONTINUER" if GameState.is_campaign_mode() else "MENU")
	replay_button.grab_focus()


func hide_screen() -> void:
	shown = false
	view.visible = false


func title_text() -> String:
	return title_label.text


func detail_text() -> String:
	return detail_label.text


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(ceil(seconds)))
	return "%d:%02d" % [total / 60, total % 60]


## Boutons (aussi appelés par les tests, sans passer par la souris).
func press_replay() -> void:
	_on_replay()


func press_menu() -> void:
	_on_menu()


func _on_replay() -> void:
	replay_pressed.emit()


func _on_menu() -> void:
	menu_pressed.emit()
