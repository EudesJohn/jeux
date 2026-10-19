extends Control
class_name LockOnMarker
## Anneau de verrouillage du HUD (DESIGN.md § 16 : « anneau de verrouillage »).
## Il suit la cible verrouillée projetée à l'écran (ARENA, § 3.2) et sert aussi
## de retour quand on change de cible en touchant un ennemi.
## Dessiné par code (draw_arc) : aucun asset, léger sur téléphone d'entrée de gamme.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const RADIUS: float = 46.0
const TICK: float = 10.0
const SIZE: float = (RADIUS + TICK) * 2.0

var target: Node3D = null
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(SIZE, SIZE)
	visible = false
	Events.lock_on_changed.connect(_on_lock_on_changed)


func _on_lock_on_changed(new_target: Node3D) -> void:
	target = new_target


func _process(delta: float) -> void:
	_pulse += delta
	if not is_instance_valid(target):
		if visible:
			visible = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		visible = false
		return
	var screen := cam.unproject_position(target.global_position + Vector3(0.0, 1.05, 0.0))
	if cam.is_position_behind(target.global_position):
		visible = false
		return
	visible = true
	position = screen - Vector2(SIZE, SIZE) * 0.5
	queue_redraw()


func _draw() -> void:
	var center := Vector2(SIZE, SIZE) * 0.5
	var pulse := 1.0 + sin(_pulse * 5.0) * 0.05
	draw_arc(center, RADIUS * pulse, 0.0, TAU, 40, GOLD, 3.0, true)
	# Quatre repères : l'anneau reste lisible même sur un fond chargé.
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var inner := center + Vector2(cos(angle), sin(angle)) * (RADIUS - TICK)
		var outer := center + Vector2(cos(angle), sin(angle)) * (RADIUS + TICK * 0.5)
		draw_line(inner, outer, GOLD, 3.0, true)
