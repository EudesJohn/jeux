extends Control
class_name LevelSelect
## Choix du niveau (PHASE 3) : lit les 5 fiches `data/levels/*.tres` et affiche
## leur contenu réel (nom, type, objectif, ennemis, pièges). Modifier un .tres
## change donc AUSSI ce qui s'affiche ici (§ 28 PHASE 3).
## La vraie carte du royaume arrive en PHASE 5.

## Les niveaux de test de la PHASE 3 (3 LANE + 2 ARENA).
const LEVELS: Array[String] = [
	"res://data/levels/lane_01.tres",
	"res://data/levels/lane_02.tres",
	"res://data/levels/lane_03.tres",
	"res://data/levels/arena_01.tres",
	"res://data/levels/arena_02.tres",
]

@onready var rows: VBoxContainer = $Panel/Root/Scroll/Rows


func _ready() -> void:
	for path in LEVELS:
		var data := load(path) as LevelData
		if data == null:
			continue
		rows.add_child(_make_button(path, data))


func _make_button(path: String, data: LevelData) -> Button:
	var button := Button.new()
	button.name = data.id
	button.custom_minimum_size = Vector2(0.0, 68.0)
	var layout := "COULOIR" if data.is_lane() else "ARÈNE"
	var night := " · nuit" if data.night else ""
	var hazards := ", ".join(data.hazards) if not data.hazards.is_empty() else "aucun"
	button.text = "%s  —  %s (%s%s)\n%d ennemis · %d vagues · pièges : %s · objectif : %s" % [
		data.display_name, layout,
		"%.0f m" % data.length_m if data.is_lane() else "rayon %.0f m" % data.arena_radius,
		night, data.enemy_total(), data.enemy_waves.size(), hazards, data.objective,
	]
	button.pressed.connect(_on_level_pressed.bind(path))
	return button


func _on_level_pressed(path: String) -> void:
	GameState.current_level_data = load(path) as LevelData
	get_tree().change_scene_to_file("res://scenes/levels/LevelBase3D.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
