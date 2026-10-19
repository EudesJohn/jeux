extends Control
class_name RescueSelect
## Choix du niveau de Sauvetage (PHASE 4, § 12.2).
##
## La liste vient des fichiers `.tres` de `data/levels/rescue` : ajouter un
## niveau ne demande aucune ligne de code ici, et les étoiles affichées sont
## lues dans `SaveManager.data["levels"]` (§ 13).
##
## Déblocage séquentiel : le niveau 1 est ouvert, le suivant s'ouvre quand le
## précédent est terminé (étoiles ≥ 1).

const LEVEL_DIR: String = "res://data/levels/rescue"

## Fiches réelles du dossier, triées par numéro de niveau (et non par nom de
## fichier : `escort_01` vient après `rescue_17`).
var levels: Array[LevelData] = []

@onready var rows: VBoxContainer = $Panel/Root/Scroll/Rows


func _ready() -> void:
	levels = _load_levels()
	for i in levels.size():
		rows.add_child(_make_button(levels[i], i))


func _load_levels() -> Array[LevelData]:
	var found: Array[LevelData] = []
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		push_warning("RescueSelect : dossier %s introuvable" % LEVEL_DIR)
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


## Un niveau est ouvert s'il est le premier ou si le précédent est terminé.
func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var previous := levels[index - 1]
	return SaveManager.has_unlocked(previous.id)


func stars_for(id: String) -> int:
	if not SaveManager.data.has("levels"):
		return 0
	var entry: Dictionary = SaveManager.data["levels"].get(id, {})
	return int(entry.get("stars", 0))


func _make_button(data: LevelData, index: int) -> Button:
	var button := Button.new()
	button.name = data.id
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.disabled = not is_unlocked(index)
	var stars := stars_for(data.id)
	var mode := "ESCORTE" if data.objective == "escort" else "SAUVETAGE"
	var night := " · NUIT" if data.night else ""
	var detail := ""
	if data.objective == "escort":
		detail = "%d villageois" % data.escorts
	else:
		detail = "%d prisonnier%s" % [data.prisoners, "s" if data.prisoners > 1 else ""]
	button.text = "%s  %02d — %s (%s%s)\n%s · %ds · %d ennemis · %s · %s" % [
		_stars_text(stars), data.number, data.display_name, mode, night,
		detail, data.time_limit, data.enemy_total(),
		"OBJECTIF VERROUILLÉ" if button.disabled else "jouable",
		"★".repeat(stars) if stars > 0 else "",
	]
	button.pressed.connect(_on_level_pressed.bind(data))
	return button


func _stars_text(stars: int) -> String:
	return "★".repeat(stars) if stars > 0 else "·"


func _on_level_pressed(data: LevelData) -> void:
	GameState.mode = GameState.GameMode.RESCUE
	GameState.current_level_data = data
	get_tree().change_scene_to_file("res://scenes/levels/LevelBase3D.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
