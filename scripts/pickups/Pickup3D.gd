extends Area3D
class_name Pickup3D
## Ramassage (DESIGN.md § 14.1 cauris, § 8.6 potion +30 vie). Les cauris tombent
## aussi des ennemis (§ 9 : `drops_cauris`).
##
## Le script construit son propre mesh graybox (PHASE 3) ; un vrai modèle .glb
## le remplacera sans toucher au code (§ 6.6).

enum Kind { CAURI, POTION }

const GOLD: Color = Color(0.89, 0.66, 0.17)
const RIVER_BLUE: Color = Color(0.17, 0.49, 0.63)
const CAURI_VALUE: int = 3
const POTION_HEAL: float = 30.0            ## § 8.6 : potion = +30 vie
const BOB_HEIGHT: float = 0.12
const SPIN_SPEED: float = 2.2
const LIFETIME: float = 0.0                ## 0 = ne disparaît pas

signal collected(pickup: Pickup3D, by: Node)

@export var kind: Kind = Kind.CAURI
@export var value: int = CAURI_VALUE

var collected_flag: bool = false

var _mesh: MeshInstance3D
var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 64                      ## couche 7 pickup (§ 19)
	collision_mask = 2 | 4                    ## joueuse et ennemis
	_build()
	_base_y = position.y
	area_entered.connect(_on_area_entered)
	if LIFETIME > 0.0:
		_expire_after(LIFETIME)


func _build() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if kind == Kind.POTION:
		var bottle := CylinderMesh.new()
		bottle.top_radius = 0.09
		bottle.bottom_radius = 0.12
		bottle.height = 0.3
		_mesh.mesh = bottle
		material.albedo_color = RIVER_BLUE
		# Bouchon doré : lisible de loin (§ 16).
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.12, 0.1, 0.12)
		cap.mesh = cap_mesh
		cap.position.y = 0.2
		var cap_material := StandardMaterial3D.new()
		cap_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cap_material.albedo_color = GOLD
		cap.material_override = cap_material
		_mesh.add_child(cap)
	else:
		var cauri := SphereMesh.new()
		cauri.radius = 0.11
		cauri.height = 0.22
		_mesh.mesh = cauri
		material.albedo_color = GOLD
	_mesh.material_override = material
	_mesh.position.y = 0.35
	add_child(_mesh)
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.35
	add_child(collision)


func _physics_process(delta: float) -> void:
	if collected_flag:
		return
	_time += delta
	_mesh.rotation.y += SPIN_SPEED * delta
	_mesh.position.y = 0.35 + sin(_time * 2.4) * BOB_HEIGHT


func _on_area_entered(area: Area3D) -> void:
	if collected_flag:
		return
	var hurtbox := area as Hurtbox3D
	if hurtbox == null:
		return
	var actor := hurtbox.owner_actor
	# Seule la joueuse ramasse (§ 14.1) : les ennemis traversent.
	if not (actor is Player3D):
		return
	collect(actor)


## Ramassage (appelé par la zone ou directement par les tests).
func collect(actor: Node) -> void:
	if collected_flag:
		return
	collected_flag = true
	var player := actor as Player3D
	if kind == Kind.POTION:
		if player != null:
			player.heal(POTION_HEAL)
	else:
		GameState.add_cauris(value)
		Events.cauris_changed.emit(int(SaveManager.data["cauris"]) + GameState.cauris_this_run)
	# § 17 : cauris (cloche) ou potion, deux timbres distincts.
	AudioManager.play_sfx(&"potion" if kind == Kind.POTION else &"cauri",
		randf_range(0.97, 1.05))
	collected.emit(self, actor)
	FX.impact(_world(), global_position + Vector3(0.0, 0.8, 0.0),
		"potion" if kind == Kind.POTION else "hit")
	queue_free()


func _expire_after(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	if not collected_flag:
		queue_free()


func _world() -> Node:
	var parent := get_parent()
	return parent if parent != null else get_tree().current_scene


## Cauri lâché par un ennemi mourant (§ 9 : `drops_cauris`).
static func cauri_at(scene_parent: Node, at: Vector3, amount: int) -> Pickup3D:
	var pickup := Pickup3D.new()
	pickup.kind = Kind.CAURI
	pickup.value = amount
	pickup.position = at + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	scene_parent.add_child(pickup)
	return pickup
