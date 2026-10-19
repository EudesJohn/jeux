extends Node3D
## Arène de test de la PHASE 1 (DESIGN.md § 28) : sol plat ocre, joueuse jouable
## (joystick + 4 boutons), un mannequin qui encaisse et riposte, caméra LANE
## automatique, HUD vie/énergie. Validation attendue : bouger, enchaîner 3 coups,
## esquiver, bloquer, voir la vie baisser/monter.
## Les vrais niveaux (LevelBase3D) arrivent en PHASE 3.

@onready var player: Player3D = $Player3D
@onready var dummy: Dummy3D = $Dummy3D
@onready var hud: HUD = $HUD


func _ready() -> void:
	Settings.apply_3d_scale()                          ## § 4 : échelle de rendu 3D
	hud.bind(player)
	# Le signal pause_pressed est branché dans CombatTest.tscn (connexion de scène).
	print("[CombatTest] prêt : %s face à %s" % [player.name, dummy.name])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_pause_pressed()


func _on_pause_pressed() -> void:
	## PHASE 1 : la pause ramène au menu principal (PHASE 5 : écran Pause).
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
