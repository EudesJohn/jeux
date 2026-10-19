extends Node3D
class_name SpectatorCamera
## Caméra du mode Spectateur (ANNEXE §2.8). Trois cadrages :
##   AUTO  — tourne lentement autour des combattants, distance selon l'écart ;
##   FREE  — glisser pour orbiter ;
##   CROWD — vue depuis les gradins, fixe et large.
## Elle n'a aucun effet sur la simulation : un spectateur ne peut pas tricher.

enum Mode { AUTO, FREE, CROWD }

@export var mode: Mode = Mode.AUTO
@export var orbit_distance: float = 12.0
@export var follow_speed: float = 5.0
@onready var cam: Camera3D = $Camera3D

var yaw: float = 0.0
var pitch: float = -0.5
var center: Vector3 = Vector3.ZERO
var has_fighters: bool = false


func _input(event: InputEvent) -> void:
	if mode != Mode.FREE or not (event is InputEventScreenDrag):
		return
	var drag := event as InputEventScreenDrag
	yaw -= drag.relative.x * 0.005
	pitch = clampf(pitch - drag.relative.y * 0.005, -1.2, -0.1)


func _process(delta: float) -> void:
	if cam == null:
		return
	var fighters := get_tree().get_nodes_in_group("players")
	has_fighters = not fighters.is_empty()
	if not has_fighters:
		return
	center = Vector3.ZERO
	for fighter in fighters:
		var node := fighter as Node3D
		if node != null:
			center += node.global_position
	center /= float(fighters.size())

	match mode:
		Mode.AUTO:
			var spread := 0.0
			if fighters.size() > 1:
				var first := fighters[0] as Node3D
				var second := fighters[1] as Node3D
				if first != null and second != null:
					spread = first.global_position.distance_to(second.global_position)
			var distance := clampf(8.0 + spread * 0.7, 8.0, 18.0)
			yaw += delta * 0.15
			_orbit(center, distance, delta)
		Mode.FREE:
			_orbit(center, orbit_distance, delta)
		Mode.CROWD:
			cam.global_position = cam.global_position.lerp(
				Vector3(0.0, 6.0, 17.0), 1.0 - exp(-3.0 * delta))
			cam.look_at(center, Vector3.UP)


func _orbit(target: Vector3, distance: float, delta: float) -> void:
	var offset := Vector3(
		sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
	cam.global_position = cam.global_position.lerp(
		target + offset, 1.0 - exp(-follow_speed * delta))
	cam.look_at(target + Vector3(0.0, 1.0, 0.0), Vector3.UP)


## AUTO -> FREE -> CROWD -> AUTO (ordre d'affichage de l'interface).
func cycle_mode() -> Mode:
	mode = (int(mode) + 1) % 3
	return mode
