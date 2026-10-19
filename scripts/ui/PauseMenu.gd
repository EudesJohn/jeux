extends CanvasLayer
class_name PauseMenu
## Écran de pause du § 16 : Reprendre, Recommencer, Réglages, Quitter.
## Construit par le code et toujours prêt (le niveau l'ajoute à sa création).
##
## La pause arrête VRAIMENT le jeu (`get_tree().paused = true`) : le timer, les
## vagues, les ennemis et la joueuse se figent. Ce menu reste actif
## (`PROCESS_MODE_ALWAYS`), sinon ses boutons ne répondraient plus.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const TEXT: Color = Color(0.96, 0.91, 0.82)

signal resumed
signal quit_requested

var level: Node = null
var view: Control
var settings_panel: SettingsPanel = null
var is_open: bool = false

var _restart_button: Button
var _resume_button: Button


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	close()


func setup(level_node: Node) -> void:
	level = level_node


func _build() -> void:
	view = Control.new()
	view.name = "View"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(view)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.04, 0.08, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	view.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.add_child(center)

	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)

	_resume_button = _button("Reprendre", "Resume")
	_resume_button.pressed.connect(close)
	column.add_child(_resume_button)

	_restart_button = _button("Recommencer", "Restart")
	_restart_button.pressed.connect(_on_restart)
	column.add_child(_restart_button)

	var settings := _button("Réglages", "Settings")
	settings.pressed.connect(_on_settings)
	column.add_child(settings)

	var quit := _button("Quitter le niveau", "Quit")
	quit.pressed.connect(_on_quit)
	column.add_child(quit)


func _button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", TEXT)
	return button


func open() -> void:
	if is_open:
		return
	# § 16 : pas de pause par-dessus l'écran de résultat.
	if level != null and (bool(level.get("completed")) or bool(level.get("failed"))):
		return
	is_open = true
	view.visible = true
	get_tree().paused = true
	if level != null:
		level.set("paused", true)
	_resume_button.grab_focus()


func close() -> void:
	is_open = false
	view.visible = false
	get_tree().paused = false
	if level != null:
		level.set("paused", false)
	resumed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _on_restart() -> void:
	close()
	if level != null and level.has_method("restart"):
		level.call("restart")


func _on_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		return
	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.closed.connect(func() -> void: settings_panel = null)
	view.add_child(settings_panel)


func _on_quit() -> void:
	close()
	quit_requested.emit()
	if level != null and level.has_method("leave_level"):
		level.call("leave_level")
