extends Ally3D
class_name Prisoner3D
## Prisonnier du § 12.2 : enfermé dans une cage, libéré par une INTERACTION DE
## 2 s (bouton « Interaction » du § 7 maintenu, ou touche E au clavier).
## Libéré, il devient un allié qui suit la joueuse comme un villageois.
##
## La cage est un graybox construit par le code (barreaux + toit). Pendant
## l'interaction, les barreaux passent du gris à l'or : le joueur voit sa
## progression sans quitter le personnage des yeux.

const HOLD_TIME: float = 2.0
const BARS_COLOR: Color = Color(0.35, 0.33, 0.31)
const GOLD: Color = Color(0.89, 0.66, 0.17)
const RANGE: float = 1.9                    ## rayon d'interaction autour de la cage

signal freed(prisoner: Prisoner3D)

var freed_flag: bool = false
var hold_time: float = 0.0
var player: Player3D = null
var cage: Node3D = null

var _bars: Array[MeshInstance3D] = []
var _bars_material: StandardMaterial3D
var _zone: Area3D = null
var _in_range: bool = false


func _ready() -> void:
	super()
	_build_cage()
	_zone = Area3D.new()
	_zone.name = "InteractZone"
	_zone.collision_layer = 128            ## couche 8 : interactable (§ 19)
	_zone.collision_mask = 2               ## la joueuse
	var shape := SphereShape3D.new()
	shape.radius = RANGE
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	_zone.add_child(collision)
	add_child(_zone)
	_zone.area_entered.connect(_on_zone_entered)
	_zone.area_exited.connect(_on_zone_exited)
	add_to_group("prisoners")


func _build_cage() -> void:
	cage = Node3D.new()
	cage.name = "Cage"
	_bars_material = StandardMaterial3D.new()
	_bars_material.albedo_color = BARS_COLOR
	# Quatre montants + un toit : lisible de loin, très bon marché.
	for corner in [Vector3(-0.7, 0.0, -0.7), Vector3(0.7, 0.0, -0.7),
			Vector3(-0.7, 0.0, 0.7), Vector3(0.7, 0.0, 0.7)]:
		var bar := MeshInstance3D.new()
		bar.name = "Bar"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.09, 2.0, 0.09)
		bar.mesh = mesh
		bar.material_override = _bars_material
		bar.position = corner + Vector3(0.0, 1.0, 0.0)
		cage.add_child(bar)
		_bars.append(bar)
	for size in [Vector3(1.5, 0.09, 0.09), Vector3(0.09, 0.09, 1.5)]:
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		beam.mesh = mesh
		beam.material_override = _bars_material
		beam.position.y = 2.0
		cage.add_child(beam)
		_bars.append(beam)
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.6, 0.09, 1.6)
	roof.mesh = roof_mesh
	roof.material_override = _bars_material
	roof.position.y = 2.05
	cage.add_child(roof)
	_bars.append(roof)
	add_child(cage)


## Signe distinctif : un bandeau de toile sur la tête (le prisonnier du village).
func _add_marker() -> void:
	var cloth := MeshInstance3D.new()
	cloth.name = "Cloth"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.3, 0.1, 0.3)
	cloth.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.82, 0.72)
	cloth.material_override = material
	cloth.position.y = 1.74
	add_child(cloth)


func _physics_process(delta: float) -> void:
	super(delta)
	if freed_flag:
		return
	# § 12.2 : il faut MAINTENIR 2 s. Lâcher le bouton fait redescendre la
	# jauge (deux fois plus vite), donc pas de libération « en passant ».
	var holding := _in_range and player != null and is_instance_valid(player) \
			and player.interact_held and player.state != Player3D.State.DEAD
	if holding:
		hold_time = minf(hold_time + delta, HOLD_TIME)
		_bars_material.albedo_color = BARS_COLOR.lerp(GOLD, hold_ratio())
		if hold_time >= HOLD_TIME:
			free_prisoner()
	else:
		if hold_time > 0.0:
			hold_time = maxf(hold_time - delta * 2.0, 0.0)
			_bars_material.albedo_color = BARS_COLOR.lerp(GOLD, hold_ratio())


func _on_zone_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null or not (hurtbox.owner_actor is Player3D):
		return
	_in_range = true
	Events.interact_target.emit(self)


func _on_zone_exited(area: Area3D) -> void:
	var hurtbox := area as Hurtbox3D
	if hurtbox == null or not (hurtbox.owner_actor is Player3D):
		return
	_in_range = false
	hold_time = 0.0
	_bars_material.albedo_color = BARS_COLOR
	Events.interact_target.emit(null)


## Libération (appelée par la jauge ou directement par les tests).
func free_prisoner() -> void:
	if freed_flag or dead:
		return
	freed_flag = true
	hold_time = HOLD_TIME
	follow = true
	cage.visible = false
	_zone.set_deferred("monitoring", false)
	FX.impact(_world(), global_position + Vector3(0.0, 1.2, 0.0), "perfect")
	Events.prisoner_freed.emit(self)
	freed.emit(self)


func hold_ratio() -> float:
	return clampf(hold_time / HOLD_TIME, 0.0, 1.0)


func in_range() -> bool:
	return _in_range
