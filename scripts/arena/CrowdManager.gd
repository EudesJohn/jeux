extends Node3D
class_name CrowdManager
## Foule des arènes (ANNEXE §2.3). **Un seul `MultiMeshInstance3D`** pour toute
## la foule : un appel de dessin, aucun os, aucune physique, aucune ombre.
## L'animation (rebond, bras levés) est faite dans `shaders/crowd.gdshader`.
##
## Densité : Faible 60, Moyenne 150, Haute 300 spectateurs. Les rangées
## lointaines peuvent être remplacées par des sprites (non câblé ici : il n'y a
## pas encore de texture de foule).

const LOW_COUNT: int = 60
const MEDIUM_COUNT: int = 150
const HIGH_COUNT: int = 300
const PALETTE: Array[Color] = [
	Color("#B3261E"), Color("#E3A92B"), Color("#1F2A5C"),
	Color("#C77D3A"), Color("#F5E9D0"), Color("#2E6B3A"),
]

@export var spectator_mesh: Mesh
@export var crowd_material: ShaderMaterial
@export var rows: int = 6
@export var first_row_radius: float = 15.0
@export var row_spacing: float = 1.1
@export var row_height_step: float = 0.9
@export var base_per_row: int = 24

var multimesh_instance: MultiMeshInstance3D
var excitement: float = 0.2
var built_count: int = 0
var _decay_per_second: float = 0.05


func _ready() -> void:
	build_crowd(Settings.crowd_density())
	if not Events.crowd_event.is_connected(_on_crowd_event):
		Events.crowd_event.connect(_on_crowd_event)


## Nombre de spectateurs pour une densité (0..1). Les trois paliers de qualité
## tombent exactement sur 60 / 150 / 300.
static func target_count(density: float) -> int:
	if density <= 0.3:
		return LOW_COUNT
	if density <= 0.6:
		return MEDIUM_COUNT
	return HIGH_COUNT


## Positions des sièges en cercle (fonction pure : testable sans rendu).
## Répartition régulière sur les rangées, avec un léger bruit angulaire pour
## éviter l'effet « armée ».
static func seat_transforms(total: int, row_count: int = 6,
		first_radius: float = 15.0, spacing: float = 1.1,
		height_step: float = 0.9) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var remaining := total
	for row in row_count:
		var seats := int(round(float(total) / float(row_count)))
		if row == row_count - 1:
			seats = remaining
		seats = mini(seats, remaining)
		remaining -= seats
		if seats <= 0:
			continue
		var radius := first_radius + float(row) * spacing
		for i in seats:
			var angle := TAU * float(i) / float(seats) + randf_range(-0.03, 0.03)
			var pos := Vector3(cos(angle) * radius, float(row) * height_step, sin(angle) * radius)
			var to_center := Vector3(-cos(angle), 0.0, -sin(angle))
			transforms.append(Transform3D(Basis.looking_at(to_center, Vector3.UP), pos))
	return transforms


func build_crowd(density: float) -> void:
	if multimesh_instance != null and is_instance_valid(multimesh_instance):
		multimesh_instance.queue_free()
		multimesh_instance = null
	var total := target_count(clampf(density, 0.0, 1.0))
	var transforms := seat_transforms(total, rows, first_row_radius, row_spacing, row_height_step)
	var colors: Array[Color] = []
	var mesh := spectator_mesh
	if mesh == null:
		mesh = _simple_spectator_mesh()
	for _i in transforms.size():
		colors.append(PALETTE[randi() % PALETTE.size()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
		mm.set_instance_custom_data(i, Color(randf(), 0.0, 0.0, 0.0))
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "Crowd"
	multimesh_instance.multimesh = mm
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if crowd_material != null:
		multimesh_instance.material_override = crowd_material
	add_child(multimesh_instance)
	built_count = transforms.size()
	_apply_excitement()


## Mesh de secours (~80 triangles) tant que le modèle de spectateur n'est pas
## livré. Le mesh définitif doit rester entre 150 et 300 triangles (§2.3).
func _simple_spectator_mesh() -> Mesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.85
	mesh.radial_segments = 6
	mesh.rings = 2
	return mesh


func _process(delta: float) -> void:
	if built_count == 0:
		return
	excitement = clampf(excitement - _decay_per_second * delta, 0.2, 1.0)
	_apply_excitement()


func _apply_excitement() -> void:
	if crowd_material != null:
		crowd_material.set_shader_parameter("excitement", excitement)
	AudioManager.set_crowd_level(excitement)


func _on_crowd_event(amount: float) -> void:
	excitement = clampf(excitement + amount, 0.0, 1.0)
	_apply_excitement()
	Events.excitement_changed.emit(excitement)


## Réactions simples pour les tests et les intégrations (pas de spam possible
## côté spectateur : l'anti-spam est dans Network).
func cheer(amount: float = 0.12) -> void:
	Events.crowd_event.emit(amount)


func crowd_size() -> int:
	return built_count
