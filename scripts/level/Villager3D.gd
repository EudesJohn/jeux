extends Ally3D
class_name Villager3D
## Villageois escorté du § 12.2 : 40 vie, il suit la joueuse dès le départ.
## « S'il meurt = échec » : c'est `EscortObjective.failed()` qui le constate, le
## villageois ne fait que mourir dignement.

const CLOTH_COLOR: Color = Color(0.20, 0.48, 0.52)

var reached_exit: bool = false


func _ready() -> void:
	super()
	follow = true
	add_to_group("escorts")


## Signe distinctif : une cape de toile bleue (le villageois, pas le prisonnier).
func _add_marker() -> void:
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.7, 0.3)
	cloth.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = CLOTH_COLOR
	cloth.material_override = material
	cloth.position = Vector3(0.0, 0.95, 0.18)
	add_child(cloth)
