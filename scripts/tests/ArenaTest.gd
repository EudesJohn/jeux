extends Node3D
## Arène ARENA de test (DESIGN.md § 3.1 « disque de 14 m de rayon » et § 28) :
## la joueuse, TROIS mannequins, la caméra ARENA avec verrouillage automatique
## et anneau de cible, le HUD complet de la PHASE 2.
## C'est la scène pour sentir le game feel : garde parfaite + contre-attaque,
## esquive parfaite, tourbillon du sabre, critiques, hit-stop.
## Les vrais niveaux (LevelBase3D) arrivent en PHASE 3.

@onready var player: Player3D = $Player3D
@onready var hud: HUD = $HUD
@onready var camera_rig: CameraRig = $CameraRig


func _ready() -> void:
	Settings.apply_3d_scale()
	hud.bind(player)
	print("[ArenaTest] ARENA prête : %d mannequins, verrouillage dans %.0f m"
		% [get_tree().get_nodes_in_group("enemies").size(), camera_rig.lock_radius])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()


func _on_pause_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
