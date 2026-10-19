extends Node3D
## Scène de réglage à chaud (DESIGN.md § 28 : « Scène de test pour ajuster les
## valeurs »). Elle charge l'arène ARENA et affiche des curseurs qui écrivent
## DIRECTEMENT dans la ressource `data/balance.tres` utilisée par la partie en
## cours : on règle, on teste au doigt, on re-règle.
##
## « IMPRIMER » enregistre les valeurs réglées dans `user://balance_tuned.tres`
## et les affiche en clair : il suffit de remplacer `data/balance.tres` par ce
## fichier (ou de recopier les lignes) pour garder les réglages.
## « RECHARGER » remet les valeurs d'origine du fichier.
## « MASQUER » cache le panneau : le joystick et les boutons redeviennent
## accessibles (le panneau recouvre la moitié gauche de l'écran).
##
## Les valeurs de combat sont relues à chaque coup : les réglages s'appliquent
## immédiatement, sans redémarrer.

const TUNED_PATH: String = "user://balance_tuned.tres"

## Champs exposés : libellé, propriété, mini, maxi, pas, cible, index (tableaux).
const FIELDS: Array[Dictionary] = [
	{"label": "Dégâts de base", "field": "base_damage", "min": 1.0, "max": 40.0, "step": 1.0},
	{"label": "Critique (%)", "field": "crit_chance", "min": 0.0, "max": 1.0, "step": 0.01},
	{"label": "Multiplicateur critique", "field": "crit_mult", "min": 1.0, "max": 3.0, "step": 0.05},
	{"label": "Hit-stop finisseur (s)", "field": "combo_hitstop", "min": 0.0, "max": 0.25, "step": 0.01, "index": 2},
	{"label": "Tremblement finisseur", "field": "combo_shake", "min": 0.0, "max": 1.0, "step": 0.02, "index": 2},
	{"label": "Fenêtre garde parfaite (s)", "field": "perfect_guard_window", "min": 0.0, "max": 0.5, "step": 0.01},
	{"label": "Contre-attaque (× dégâts)", "field": "perfect_guard_counter_mult", "min": 1.0, "max": 4.0, "step": 0.1},
	{"label": "Stabilité de garde max", "field": "guard_stability_max", "min": 10.0, "max": 60.0, "step": 5.0},
	{"label": "Fenêtre esquive parfaite (s)", "field": "perfect_dodge_window", "min": 0.0, "max": 0.4, "step": 0.01},
	{"label": "Distance d'esquive (m)", "field": "dodge_distance", "min": 1.0, "max": 8.0, "step": 0.2},
	{"label": "Coût du spécial", "field": "special_cost", "min": 20.0, "max": 100.0, "step": 5.0},
	{"label": "Dégâts du spécial (×)", "field": "special_damage_mult", "min": 1.0, "max": 6.0, "step": 0.5},
	{"label": "Rayon du tourbillon (m)", "field": "special_radius", "min": 1.0, "max": 5.0, "step": 0.1},
	{"label": "Vie du mannequin", "field": "dummy_health", "min": 30.0, "max": 300.0, "step": 10.0},
	{"label": "Verrouillage caméra (m)", "field": "lock_radius", "min": 3.0, "max": 14.0, "step": 0.5,
		"target": "camera"},
]

@onready var player: Player3D = $Player3D
@onready var hud: HUD = $HUD
@onready var camera_rig: CameraRig = $CameraRig
@onready var panel: PanelContainer = $UI/Panel
@onready var rows: VBoxContainer = $UI/Panel/Root/Scroll/Rows
@onready var toggle: Button = $UI/Toggle
@onready var status: Label = $UI/Panel/Root/Status

var balance: Balance
## Valeurs d'origine du fichier (bouton RECHARGER).
var _original: Dictionary = {}
var _original_lock_radius: float = 8.0


func _ready() -> void:
	Settings.apply_3d_scale()
	hud.bind(player)
	balance = player.balance
	_snapshot()
	_build_rows()
	$UI/Panel/Root/Buttons/Print.pressed.connect(_on_print)
	$UI/Panel/Root/Buttons/Reload.pressed.connect(_on_reload)
	toggle.pressed.connect(_on_toggle)
	_update_status("Réglages à chaud : %s" % balance.resource_path)
	print("[BalanceTest] %d réglages exposés, valeurs lues dans %s"
		% [FIELDS.size(), balance.resource_path])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()


## Bouton Pause (§ 7) : retour au menu principal.
func _on_pause_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


# -----------------------------------------------------------------#
#                       PANNEAU DE RÉGLAGE                         #
# -----------------------------------------------------------------#

func _build_rows() -> void:
	for definition in FIELDS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(definition["label"])
		label.custom_minimum_size = Vector2(232.0, 22.0)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = float(definition["min"])
		slider.max_value = float(definition["max"])
		slider.step = float(definition["step"])
		slider.value = _read(definition)
		slider.custom_minimum_size = Vector2(150.0, 22.0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var value_label := Label.new()
		value_label.text = _format(slider.value)
		value_label.custom_minimum_size = Vector2(62.0, 22.0)
		value_label.add_theme_font_size_override("font_size", 14)
		row.add_child(value_label)
		slider.value_changed.connect(_on_slider_changed.bind(definition, value_label))
		rows.add_child(row)


func _on_slider_changed(value: float, definition: Dictionary, value_label: Label) -> void:
	_write(definition, value)
	value_label.text = _format(value)


func _target_of(definition: Dictionary) -> Object:
	return camera_rig if str(definition.get("target", "balance")) == "camera" else balance


func _read(definition: Dictionary) -> float:
	var target := _target_of(definition)
	var value: Variant = target.get(str(definition["field"]))
	if definition.has("index"):
		var array := value as PackedFloat32Array
		var index: int = definition["index"]
		return array[index] if index < array.size() else 0.0
	return float(value)


func _write(definition: Dictionary, value: float) -> void:
	var target := _target_of(definition)
	var field := str(definition["field"])
	if definition.has("index"):
		var array := (target.get(field) as PackedFloat32Array).duplicate()
		var index: int = definition["index"]
		if index >= array.size():
			return
		array[index] = value
		target.set(field, array)
	else:
		target.set(field, value)


func _format(value: float) -> String:
	return "%.2f" % value


func _snapshot() -> void:
	for property in balance.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			_original[property["name"]] = balance.get(property["name"])
	_original_lock_radius = camera_rig.lock_radius


func _on_print() -> void:
	var error := ResourceSaver.save(balance, TUNED_PATH)
	var path := ProjectSettings.globalize_path(TUNED_PATH)
	if error != OK:
		_update_status("ÉCHEC de l'enregistrement (%d)" % error)
		return
	_update_status("Réglages enregistrés : %s" % path)
	print("--- Balance réglée (à copier dans data/balance.tres) ---")
	print("Fichier complet : ", path)
	for definition in FIELDS:
		print("  %s = %s" % [definition["field"], _format(_read(definition))])


func _on_reload() -> void:
	for field in _original:
		balance.set(field, _original[field])
	camera_rig.lock_radius = _original_lock_radius
	for row in rows.get_children():
		var slider := row.get_child(1) as HSlider
		var value_label := row.get_child(2) as Label
		var definition: Dictionary = FIELDS[rows.get_children().find(row)]
		slider.set_value_no_signal(_read(definition))
		value_label.text = _format(slider.value)
	_update_status("Valeurs d'origine de %s restaurées" % balance.resource_path)


func _on_toggle() -> void:
	panel.visible = not panel.visible
	toggle.text = "PANNEAU" if not panel.visible else "MASQUER"


func _update_status(text: String) -> void:
	status.text = text
