extends Node3D
class_name TargetRing
## Anneau doré sous la cible verrouillée (DESIGN.md § 3.2 : « Un petit anneau
## doré marque la cible »). Il tourne lentement et pulse : lisible en ARENA.
## Construit en primitives (TorusMesh) : aucun asset à fournir, remplaçable
## plus tard sans toucher au code.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const RADIUS: float = 0.65
const HEIGHT: float = 0.06

var _mesh_instance: MeshInstance3D
var _spin: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = GOLD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.85
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.06
	torus.outer_radius = RADIUS
	torus.rings = 16
	torus.ring_segments = 12
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = torus
	_mesh_instance.material_override = material
	add_child(_mesh_instance)


func _process(delta: float) -> void:
	_spin += delta * 1.6
	_mesh_instance.rotation.y = _spin
	# Pulsation douce : la cible se repère du coin de l'œil.
	var pulse := 1.0 + sin(_spin * 2.0) * 0.06
	_mesh_instance.scale = Vector3(pulse, 1.0, pulse)
