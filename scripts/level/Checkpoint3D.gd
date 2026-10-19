extends Area3D
class_name Checkpoint3D
## Checkpoint (§ 13 : « un à mi-niveau »). La joueuse le traverse, il s'allume en
## or et devient le point de réapparition (`LevelBase3D`).
## Une réapparition par niveau en Normal, illimitée en Facile (§ 13) : c'est le
## niveau qui décide, le checkpoint ne fait que mémoriser l'endroit.

const GOLD: Color = Color(0.89, 0.66, 0.17)
const STONE: Color = Color(0.42, 0.40, 0.38)

signal activated(checkpoint: Checkpoint3D, position: Vector3)

@export var radius: float = 1.6

var active: bool = false
## Position de réapparition : un peu devant le checkpoint.
var respawn_position: Vector3 = Vector3.ZERO

var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 128                     ## couche 8 « interactable » (§ 19)
	collision_mask = 2                        ## joueuse
	_build()
	respawn_position = global_position + Vector3(0.0, 0.1, 1.2)
	area_entered.connect(_on_area_entered)


func _build() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	# Totem graybox : un mât + un anneau qui s'allume à l'activation.
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.12
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = 2.2
	pole.mesh = pole_mesh
	pole.position.y = 1.1
	var pole_material := StandardMaterial3D.new()
	pole_material.albedo_color = STONE
	pole.material_override = pole_material
	add_child(pole)

	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.3
	ring_mesh.outer_radius = 0.45
	_ring.mesh = ring_mesh
	_ring.position = Vector3(0.0, 1.5, 0.0)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = STONE
	_ring.material_override = _ring_material
	add_child(_ring)


func _physics_process(delta: float) -> void:
	_ring.rotation.y += delta * (2.0 if active else 0.4)


func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null or not (hurtbox.owner_actor is Player3D):
		return
	activate()


## Activation (appelée par la zone ou par les tests).
func activate() -> void:
	if active:
		return
	active = true
	_ring_material.albedo_color = GOLD
	activated.emit(self, respawn_position)
	FX.impact(_world(), global_position + Vector3(0.0, 1.5, 0.0), "perfect")


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene
