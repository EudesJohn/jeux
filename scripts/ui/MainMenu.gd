extends Node3D
## Menu principal (§ 16, PHASE 5) : Jouer, Coop WiFi, Armurerie, Réglages,
## Quitter, plus un accès discret aux scènes de test des phases précédentes.
##
## L'interface est construite par le code : la scène ne garde que le fond 3D
## (le cube qui tourne, en attendant la guerrière du § 16). Les boutons de test
## restent là pour rejouer PHASE 1 à 4 sans passer par la campagne.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)
const BACKGROUND: Color = Color(0.10, 0.078, 0.067)

@onready var cube: MeshInstance3D = $Cube

var settings_panel: SettingsPanel = null
var play_button: Button
var coop_button: Button


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	cube.rotation.y += delta * 0.8


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := Label.new()
	title.name = "Title"
	title.text = "ABOMEY WARRIORS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18.0
	title.offset_bottom = 76.0
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Libère les prisonniers. Traverse le royaume."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(TEXT, 0.75))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 74.0
	subtitle.offset_bottom = 100.0
	root.add_child(subtitle)

	var column := VBoxContainer.new()
	column.name = "Menu"
	column.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_theme_constant_override("separation", 12)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -210.0
	column.offset_right = 210.0
	column.offset_top = -200.0
	column.offset_bottom = 240.0
	root.add_child(column)

	play_button = _button("Jouer", "Play", true)
	play_button.pressed.connect(_on_play)
	column.add_child(play_button)

	coop_button = _button("Coop WiFi", "Coop", false)
	coop_button.tooltip_text = "2 joueuses sur le même WiFi local (hotspot ou box)."
	coop_button.pressed.connect(_on_open_lobby)
	column.add_child(coop_button)

	var armory := _button("Armurerie", "Armory", false)
	armory.pressed.connect(_on_open_shop)
	column.add_child(armory)

	var achievements := _button("Succès", "Achievements", false)
	achievements.pressed.connect(_on_open_achievements)
	column.add_child(achievements)

	var settings := _button("Réglages", "Settings", false)
	settings.pressed.connect(_on_open_settings)
	column.add_child(settings)

	var quit := _button("Quitter", "Quit", false)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)

	# Accès aux scènes de test (PHASE 1 à 4) : petit, en bas.
	var tests := HBoxContainer.new()
	tests.name = "Tests"
	tests.alignment = BoxContainer.ALIGNMENT_CENTER
	tests.add_theme_constant_override("separation", 8)
	tests.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tests.offset_top = -78.0
	tests.offset_bottom = -30.0
	root.add_child(tests)

	var test_buttons: Array = [
		["Niveaux PHASE 3", _on_open_level_select],
		["Sauvetage PHASE 4", _on_open_rescue],
		["Arène PHASE 2", _on_open_arena_test],
		["Réglage", _on_open_balance_test],
		["Combat PHASE 1", _on_open_combat_test],
		["ModelViewer", _on_open_model_viewer],
	]
	for entry in test_buttons:
		var button := Button.new()
		button.text = String(entry[0])
		button.custom_minimum_size = Vector2(150.0, 44.0)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(entry[1] as Callable)
		tests.add_child(button)


func _button(text: String, node_name: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.add_theme_font_size_override("font_size", 24 if primary else 21)
	button.add_theme_color_override("font_color", GOLD if primary else TEXT)
	return button


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


## PHASE 7 : le lobby coop (hôte / invité) dans `Network`.
func _on_open_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Lobby.tscn")


func _on_open_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Shop.tscn")


## PHASE 8 : écran des succès.
func _on_open_achievements() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/AchievementsScreen.tscn")


func _on_open_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		return
	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.closed.connect(func() -> void: settings_panel = null)
	add_child(settings_panel)


# -----------------------------------------------------------------#
#              ACCÈS AUX SCÈNES DE TEST (PHASE 1 à 4)              #
# -----------------------------------------------------------------#

func _on_open_rescue() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/RescueSelect.tscn")


func _on_open_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/LevelSelect.tscn")


func _on_open_arena_test() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/ArenaTest.tscn")


func _on_open_balance_test() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/BalanceTest.tscn")


func _on_open_combat_test() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/CombatTest.tscn")


func _on_open_model_viewer() -> void:
	get_tree().change_scene_to_file("res://scenes/tests/ModelViewer.tscn")
