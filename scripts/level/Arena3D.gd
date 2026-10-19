extends Node3D
class_name Arena3D
## Arène circulaire de l'ANNEXE §2.2 : sol de terre battue, 6 gradins, foule
## MultiMesh, 4 points d'apparition et une tribune. Rayon de combat 13 m,
## gradins de 15 à 20 m.
##
## Aucune texture : les matériaux sont des couleurs de la DA (rouge Dahomey,
## indigo, or, terre). Les 4 ambiances (royale, marché, fleuve, nuit) se
## règlent par les couleurs et la lumière, sans dupliquer le script.

@export var arena_radius: float = 13.0
@export var crowd_rows: int = 6
@export var first_row_radius: float = 15.0
@export var ambiance: String = "royale"   ## royale / marche / fleuve / nuit

var floor_mesh: MeshInstance3D
var crowd: CrowdManager
var spawns: Array[Marker3D] = []

const COLORS := {
	"royale": {"ground": Color(0.55, 0.42, 0.28), "stand": Color(0.42, 0.16, 0.12),
		"sky": Color(0.98, 0.78, 0.45), "light": 1.0},
	"marche": {"ground": Color(0.62, 0.50, 0.34), "stand": Color(0.55, 0.35, 0.18),
		"sky": Color(1.0, 0.86, 0.60), "light": 1.1},
	"fleuve": {"ground": Color(0.58, 0.50, 0.38), "stand": Color(0.24, 0.34, 0.38),
		"sky": Color(1.0, 0.68, 0.42), "light": 0.9},
	"nuit": {"ground": Color(0.28, 0.24, 0.20), "stand": Color(0.16, 0.14, 0.18),
		"sky": Color(0.10, 0.10, 0.22), "light": 0.35},
}


func _ready() -> void:
	build_arena()


func build_arena() -> void:
	var palette: Dictionary = COLORS.get(ambiance, COLORS["royale"])
	_build_ground(palette)
	_build_stands(palette)
	_build_spawns()
	_build_crowd()
	_build_light(palette)


func _build_ground(palette: Dictionary) -> void:
	floor_mesh = MeshInstance3D.new()
	floor_mesh.name = "Ground"
	var mesh := CylinderMesh.new()
	mesh.top_radius = arena_radius
	mesh.bottom_radius = arena_radius
	mesh.height = 0.4
	mesh.radial_segments = 40
	floor_mesh.mesh = mesh
	floor_mesh.position.y = -0.2
	floor_mesh.material_override = _material(palette["ground"])
	add_child(floor_mesh)

	# Liseré doré au bord de la zone de combat.
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = arena_radius - 0.15
	torus.outer_radius = arena_radius + 0.05
	torus.rings = 40
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = 0.02
	ring.material_override = _material(Color(0.89, 0.66, 0.17))
	add_child(ring)


func _build_stands(palette: Dictionary) -> void:
	for row in crowd_rows:
		var step := MeshInstance3D.new()
		step.name = "Stand%d" % row
		var torus := TorusMesh.new()
		var inner := first_row_radius + float(row) * 1.1
		torus.inner_radius = inner
		torus.outer_radius = inner + 0.95
		torus.rings = 40
		torus.ring_segments = 6
		step.mesh = torus
		step.position.y = 0.6 + float(row) * 0.9
		step.material_override = _material(palette["stand"])
		add_child(step)

	# Tribune royale au nord : estrade et poteaux dorés.
	var tribune := Node3D.new()
	tribune.name = "Tribune"
	tribune.position = Vector3(0.0, 3.0, -first_row_radius - 1.4)
	add_child(tribune)
	var deck := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 0.3, 2.2)
	deck.mesh = box
	deck.material_override = _material(Color(0.30, 0.12, 0.10))
	tribune.add_child(deck)
	for side in [-2.6, 2.6]:
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.12
		post_mesh.bottom_radius = 0.16
		post_mesh.height = 3.4
		post.mesh = post_mesh
		post.position = Vector3(side, 1.7, 0.0)
		post.material_override = _material(Color(0.89, 0.66, 0.17))
		tribune.add_child(post)
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(6.4, 0.12, 2.6)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.0, 3.4, 0.0)
	canopy.material_override = _material(Color(0.70, 0.15, 0.12))
	tribune.add_child(canopy)


func _build_spawns() -> void:
	spawns.clear()
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % (i + 1)
		marker.position = Vector3(cos(angle) * 8.0, 0.1, sin(angle) * 8.0)
		marker.add_to_group("arena_spawn")
		add_child(marker)
		spawns.append(marker)


func _build_crowd() -> void:
	crowd = CrowdManager.new()
	crowd.name = "CrowdManager"
	crowd.rows = crowd_rows
	crowd.first_row_radius = first_row_radius
	crowd.row_spacing = 1.1
	crowd.row_height_step = 0.9
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.85
	mesh.radial_segments = 6
	mesh.rings = 2
	crowd.spectator_mesh = mesh
	var material := ShaderMaterial.new()
	var shader := load("res://shaders/crowd.gdshader") as Shader
	if shader != null:
		material.shader = shader
	material.set_shader_parameter("excitement", 0.2)
	crowd.crowd_material = material
	add_child(crowd)


func _build_light(palette: Dictionary) -> void:
	var light := DirectionalLight3D.new()
	light.name = "ArenaLight"
	light.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(28.0), 0.0)
	light.light_energy = float(palette["light"])
	light.shadow_enabled = false
	add_child(light)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = palette["sky"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = palette["sky"]
	environment.ambient_light_energy = 0.45
	env.environment = environment
	add_child(env)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


## Point d'apparition pour un combattant (0 à 3).
func spawn_position(index: int) -> Vector3:
	if spawns.is_empty():
		return Vector3.ZERO
	return spawns[clampi(index, 0, spawns.size() - 1)].global_position


func spawn_count() -> int:
	return spawns.size()
