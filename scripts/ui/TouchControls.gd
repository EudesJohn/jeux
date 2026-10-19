extends CanvasLayer
class_name TouchControls
## Contrôles tactiles de jeu (DESIGN.md § 7) : joystick flottant dans la moitié
## gauche, 4 boutons d'action à droite (positions exactes du tableau § 7), un
## bouton « Interaction » (PHASE 4 : près d'un prisonnier) et bouton Pause. Les
## boutons parlent au gameplay uniquement par Events.touch_action ; ce script ne
## signale que la Pause.

signal pause_pressed

@onready var pause_button: TouchButton = $Pause
## § 7 : « Interaction (apparaît près d'un prisonnier/coffre) ».
@onready var interact_button: TouchButton = $Interact


func _ready() -> void:
	pause_button.tapped.connect(_on_pause_tapped)
	set_interact_visible(false)


func _on_pause_tapped() -> void:
	pause_pressed.emit()


## Affiche ou masque le bouton « Interaction ». Masqué, il ne capte plus aucun
## doigt : c'est le niveau qui l'allume quand une cage est à portée (§ 12.2).
func set_interact_visible(visible_now: bool) -> void:
	if interact_button == null:
		return
	if interact_button.visible == visible_now:
		return
	interact_button.visible = visible_now
	interact_button.set_process_input(visible_now)
	if not visible_now:
		interact_button.release_now()
